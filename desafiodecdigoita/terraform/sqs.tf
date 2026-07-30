resource "aws_sqs_queue" "main" {
  name                       = "${var.app_name}_conta-bancaria-criada"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600  # 4 days
  receive_wait_time_seconds  = 10

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 5
  })

  tags = { Name = "${var.app_name}_conta-bancaria-criada" }
}

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.app_name}_conta-bancaria-criada-dlq"
  message_retention_seconds = 1209600  # 14 days

  tags = { Name = "${var.app_name}_conta-bancaria-criada-dlq" }
}

resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.main.arn]
  })
}