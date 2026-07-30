# ==========================================
# IAM User Read-Only para Observabilidade
# ==========================================
# Este ficheiro cria um IAM user com acesso
# somente leitura ao CloudWatch e X-Ray.
# 
# Uso único (não faz parte do run-aws.sh):
#   terraform apply -target=aws_iam_user.observability_reader \
#                   -target=aws_iam_user_policy_attachment.observability_reader_cloudwatch \
#                   -target=aws_iam_user_policy_attachment.observability_reader_xray \
#                   -target=aws_iam_access_key.observability_reader \
#                   -var-file="environments/dev.tfvars"
# ==========================================

resource "aws_iam_user" "observability_reader" {
  name = "${var.app_name}_observability_reader"
  path = "/"

  tags = {
    Name        = "${var.app_name}_observability_reader"
    Description = "Read-only access to CloudWatch and X-Ray"
  }
}

# CloudWatch ReadOnly
resource "aws_iam_user_policy_attachment" "observability_reader_cloudwatch" {
  user       = aws_iam_user.observability_reader.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

# X-Ray ReadOnly
resource "aws_iam_user_policy_attachment" "observability_reader_xray" {
  user       = aws_iam_user.observability_reader.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayReadOnlyAccess"
}

# Access Key
resource "aws_iam_access_key" "observability_reader" {
  user = aws_iam_user.observability_reader.name
}

output "observability_reader_access_key_id" {
  description = "Access Key ID for observability reader"
  value       = aws_iam_access_key.observability_reader.id
  sensitive   = false
}

output "observability_reader_secret_access_key" {
  description = "Secret Access Key for observability reader"
  value       = aws_iam_access_key.observability_reader.secret
  sensitive   = true
}

output "observability_reader_console_url" {
  description = "AWS Console login URL for observability reader"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}"
}