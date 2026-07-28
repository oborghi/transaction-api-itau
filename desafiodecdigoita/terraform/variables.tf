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

variable "container_image" {
  description = "Docker image for the API"
  type        = string
  default     = "transaction-api:latest"
}

variable "container_cpu" {
  description = "CPU units for the container (1024 = 1 vCPU)"
  type        = number
  default     = 512
}

variable "container_memory" {
  description = "Memory for the container in MiB"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 2
}

variable "db_instance_class" {
  description = "DocumentDB instance class"
  type        = string
  default     = "db.r6g.large"
}

variable "db_master_username" {
  description = "DocumentDB master username"
  type        = string
  sensitive   = true
}

variable "db_master_password" {
  description = "DocumentDB master password"
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

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}