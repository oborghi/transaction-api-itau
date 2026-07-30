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
  description = "Project name used for resource naming (prefixo para todos os recursos)"
  type        = string
  default     = "desafiodecdigoita"
}

variable "app_name" {
  description = "Application name used for AWS resource naming (padrão: <app_name>_<recurso>)"
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

# ==========================================
# EKS Variables
# ==========================================
variable "node_instance_type" {
  description = "EC2 instance type for EKS node group"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired number of nodes in EKS node group"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of nodes in EKS node group"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of nodes in EKS node group"
  type        = number
  default     = 5
}

# ==========================================
# DocumentDB Variables
# ==========================================
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

# ==========================================
# App Variables
# ==========================================
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

variable "domain_name" {
  description = "Domain name for the ACM certificate (HTTPS)"
  type        = string
  default     = ""
}
