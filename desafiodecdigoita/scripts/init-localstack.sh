#!/bin/bash
# Create SQS queues on LocalStack startup
echo "Creating SQS queues..."

aws --endpoint-url=http://localhost:4566 --region sa-east-1 \
  sqs create-queue --queue-name conta-bancaria-criada

aws --endpoint-url=http://localhost:4566 --region sa-east-1 \
  sqs create-queue --queue-name conta-bancaria-criada-dlq

echo "SQS queues created successfully."