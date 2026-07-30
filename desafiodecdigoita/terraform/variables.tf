variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "sa-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "desafiodecdigoita"
}

variable "app_name" {
  description = "Application name used for AWS resource naming"
  type        = string
  default     = "transaction-api"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["sa-east-1a", "sa-east-1b"]
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ==========================================
# Sensitive Variables (passed via -var or env)
# ==========================================
variable "db_master_username" {
  description = "MongoDB master username"
  type        = string
  sensitive   = true
  default     = "admin"
}

variable "db_master_password" {
  description = "MongoDB master password"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT secret for token generation"
  type        = string
  sensitive   = true
}

variable "api_client_secret" {
  description = "API client secret for authentication"
  type        = string
  sensitive   = true
}

variable "ec2_key_name" {
  description = "EC2 key pair name for SSH access to MongoDB (optional)"
  type        = string
  default     = ""
}
