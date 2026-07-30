# ==========================================
# AWS Secrets Manager
# ==========================================
# Stores JWT, API credentials, and SQS config
# MongoDB URI is passed via environment variable (not secret)
# ==========================================

# JWT Secret
resource "aws_secretsmanager_secret" "jwt" {
  name        = "${var.app_name}/jwt"
  description = "JWT signing key and configuration"

  tags = {
    Name        = "${var.app_name}_jwt"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id = aws_secretsmanager_secret.jwt.id
  secret_string = jsonencode({
    secret = var.jwt_secret
    issuer = "transaction-api"
  })
}

# API Credentials
resource "aws_secretsmanager_secret" "credentials" {
  name        = "${var.app_name}/credentials"
  description = "API client credentials"

  tags = {
    Name        = "${var.app_name}_credentials"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "credentials" {
  secret_id = aws_secretsmanager_secret.credentials.id
  secret_string = jsonencode({
    client_id     = "transaction-api-client"
    client_secret = var.api_client_secret
  })
}

# SQS Configuration
resource "aws_secretsmanager_secret" "sqs" {
  name        = "${var.app_name}/sqs"
  description = "SQS queue configuration"

  tags = {
    Name        = "${var.app_name}_sqs"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "sqs" {
  secret_id = aws_secretsmanager_secret.sqs.id
  secret_string = jsonencode({
    region          = var.aws_region
    queue_url       = aws_sqs_queue.main.id
    dlq_url         = aws_sqs_queue.dlq.id
    poll_interval   = "5000"
  })
}