package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/aws/aws-sdk-go-v2/service/sqs/types"
	"github.com/google/uuid"
)

type AccountMessage struct {
	Account AccountData `json:"account"`
}

type AccountData struct {
	ID        string `json:"id"`
	Owner     string `json:"owner"`
	CreatedAt string `json:"created_at"`
	Status    string `json:"status"`
}

func main() {
	queueName := os.Getenv("QUEUE_NAME")
	if queueName == "" {
		queueName = "conta-bancaria-criada"
	}

	endpoint := os.Getenv("LOCALSTACK_ENDPOINT")
	if endpoint == "" {
		endpoint = "http://localhost:4566"
	}

	totalAccounts := 100000
	if v := os.Getenv("TOTAL_ACCOUNTS"); v != "" {
		fmt.Sscanf(v, "%d", &totalAccounts)
	}

	region := os.Getenv("AWS_DEFAULT_REGION")
	if region == "" {
		region = "sa-east-1"
	}

	// Resolve the queue URL
	cfg, err := config.LoadDefaultConfig(context.Background(),
		config.WithRegion(region),
		config.WithEndpointResolverWithOptions(aws.EndpointResolverWithOptionsFunc(
			func(service, region string, options ...interface{}) (aws.Endpoint, error) {
				return aws.Endpoint{
					URL:               endpoint,
					SigningRegion:     region,
					HostnameImmutable: true,
				}, nil
			},
		)),
	)
	if err != nil {
		log.Fatalf("unable to load SDK config, %v", err)
	}

	client := sqs.NewFromConfig(cfg)

	// Get queue URL
	getQueueURL, err := client.GetQueueUrl(context.Background(), &sqs.GetQueueUrlInput{
		QueueName: aws.String(queueName),
	})
	if err != nil {
		log.Fatalf("unable to get queue URL, %v", err)
	}
	queueURL := *getQueueURL.QueueUrl

	log.Printf("🚀 Starting message generator for queue: %s", queueURL)
	log.Printf("📊 Total accounts to generate: %d", totalAccounts)

	batchSize := 10
	sent := 0
	startTime := time.Now()

	for i := 0; i < totalAccounts; i += batchSize {
		count := batchSize
		if i+batchSize > totalAccounts {
			count = totalAccounts - i
		}

		var entries []types.SendMessageBatchRequestEntry
		for j := 0; j < count; j++ {
			accountID := uuid.New().String()
			ownerID := uuid.New().String()
			createdAt := fmt.Sprintf("%d", time.Now().Unix())

			msg := AccountMessage{
				Account: AccountData{
					ID:        accountID,
					Owner:     ownerID,
					CreatedAt: createdAt,
					Status:    "ENABLED",
				},
			}

			body, _ := json.Marshal(msg)

			entries = append(entries, types.SendMessageBatchRequestEntry{
				Id:          aws.String(fmt.Sprintf("msg-%d", i+j)),
				MessageBody: aws.String(string(body)),
			})
		}

		_, err := client.SendMessageBatch(context.Background(), &sqs.SendMessageBatchInput{
			QueueUrl: aws.String(queueURL),
			Entries:  entries,
		})
		if err != nil {
			log.Printf("❌ Error sending batch %d: %v", i/batchSize, err)
			time.Sleep(1 * time.Second)
			continue
		}

		sent += count
		elapsed := time.Since(startTime)
		rate := float64(sent) / elapsed.Seconds()
		log.Printf("✅ Sent %d/%d accounts (%.0f msg/s)", sent, totalAccounts, rate)
	}

	elapsed := time.Since(startTime)
	log.Printf("✅ Done! Sent %d accounts in %s", sent, elapsed)
}
