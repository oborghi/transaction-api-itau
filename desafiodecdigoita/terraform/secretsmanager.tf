# ==========================================
# AWS Secrets Manager
# ==========================================

# MongoDB Secret
resource "aws_secretsmanager_secret" "mongodb" {
  name        = "${var.project_name}/mongodb"
  description = "MongoDB connection credentials"
  tags = {
    Name        = "${var.project_name}-mongodb"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "mongodb" {
  secret_id = aws_secretsmanager_secret.mongodb.id
  secret_string = jsonencode({
    uri      = "mongodb://${aws_docdb_cluster.main.master_username}:${aws_docdb_cluster.main.master_password}@${aws_docdb_cluster.main.endpoint}:27017/transaction_db?tls=true&replicaSet=rs0&readPreference=secondaryPreferred"
    username = aws_docdb_cluster.main.master_username
    password = aws_docdb_cluster.main.master_password
  })
}

# JWT Secret
resource "aws_secretsmanager_secret" "jwt" {
  name        = "${var.project_name}/jwt"
  description = "JWT signing key and configuration"
  tags = {
    Name        = "${var.project_name}-jwt"
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
  name        = "${var.project_name}/credentials"
  description = "API client credentials"
  tags = {
    Name        = "${var.project_name}-credentials"
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

# SQS Secret (access keys if needed)
resource "aws_secretsmanager_secret" "sqs" {
  name        = "${var.project_name}/sqs"
  description = "SQS configuration"
  tags = {
    Name        = "${var.project_name}-sqs"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "sqs" {
  secret_id = aws_secretsmanager_secret.sqs.id
  secret_string = jsonencode({
    region = var.aws_region
  })
}

# ==========================================
# IAM Policy for Secrets Manager Access
# ==========================================

resource "aws_iam_policy" "secrets_manager_access" {
  name        = "${var.project_name}-secrets-manager-access"
  description = "Allow ECS tasks to read secrets from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.mongodb.arn,
          aws_secretsmanager_secret.jwt.arn,
          aws_secretsmanager_secret.credentials.arn,
          aws_secretsmanager_secret.sqs.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "secrets_manager_access" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.secrets_manager_access.arn
}