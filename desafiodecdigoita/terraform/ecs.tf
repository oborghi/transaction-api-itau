# ==========================================
# ECS Fargate Cluster + Services
# ==========================================
# Free Tier: Fargate with minimal CPU/Memory
# Runs in public subnets (no NAT needed)
# ==========================================

resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}_cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }


  tags = { Name = "${var.app_name}_cluster" }
}

# CloudWatch Log Group for ECS
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.app_name}"
  retention_in_days = 30
  tags              = { Name = "${var.app_name}_ecs_logs" }
}

# ==========================================
# Security Group for App ECS Tasks
# ==========================================
resource "aws_security_group" "ecs" {
  name_prefix = "${var.app_name}_ecs_"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "ALB to ECS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = { Name = "${var.app_name}_ecs_sg" }

  lifecycle { create_before_destroy = true }
}

# ==========================================
# Security Group for MongoDB ECS Tasks
# ==========================================
resource "aws_security_group" "mongodb" {
  name_prefix = "${var.app_name}_mongodb_"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
    description     = "App to MongoDB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = { Name = "${var.app_name}_mongodb_sg" }

  lifecycle { create_before_destroy = true }
}

# ==========================================
# App Task Definition (sem MongoDB)
# ==========================================
resource "aws_ecs_task_definition" "app" {
  family                   = var.app_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "${var.app_name}-app"
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      environment = [
        { name = "SERVER_PORT",              value = "8080" },
        { name = "AWS_DEFAULT_REGION",       value = var.aws_region },
        { name = "AWS_SECRETS_ENABLED",      value = "true" },
        { name = "CLOUDWATCH_ENABLED",       value = "true" },
        { name = "CLOUDWATCH_NAMESPACE",     value = "TransactionAPI" },
        { name = "ACTUATOR_EXPOSURE",        value = "health,info,metrics" },
        { name = "SQS_POLL_INTERVAL",        value = "5000" },
        { name = "JWT_EXPIRATION",           value = "86400" },
        { name = "LOG_LEVEL",                value = "INFO" },
        { name = "LOG_LEVEL_MONGODB",        value = "WARN" },
        { name = "S3_LOG_BUCKET",            value = aws_s3_bucket.logs.bucket },
        { name = "SERVICE_NAME",             value = var.app_name },
        { name = "ENVIRONMENT",              value = var.environment },
        { name = "SQS_QUEUE_URL",            value = aws_sqs_queue.main.url },
        { name = "SQS_DLQ_URL",              value = aws_sqs_queue.dlq.url },
        { name = "SPRING_DATA_MONGODB_URI",  value = "mongodb://${var.db_master_username}:${urlencode(var.db_master_password)}@mongodb.${var.app_name}.internal:27017/transaction_db?authSource=admin" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/actuator/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 120
      }
    },
    {
      name      = "xray-daemon"
      image     = "public.ecr.aws/xray/aws-xray-daemon:latest"
      essential = false

      portMappings = [
        {
          containerPort = 2000
          protocol      = "udp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs-xray"
        }
      }
    }
  ])

  tags = { Name = "${var.app_name}_task_def" }
}

# ==========================================
# MongoDB Task Definition
# ==========================================
resource "aws_ecs_task_definition" "mongodb" {
  family                   = "${var.app_name}-mongodb"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  volume {
    name = "mongodb_data"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.mongodb.id
      transit_encryption = "ENABLED"
    }
  }

  container_definitions = jsonencode([
    {
      name      = "mongodb"
      image     = "mongo:7.0"
      essential = true

      portMappings = [
        {
          containerPort = 27017
          protocol      = "tcp"
        }
      ]

      command = ["sh", "-c", "rm -f /data/db/mongod.lock && exec docker-entrypoint.sh mongod"]

      environment = [
        { name = "MONGO_INITDB_ROOT_USERNAME", value = var.db_master_username },
        { name = "MONGO_INITDB_ROOT_PASSWORD", value = var.db_master_password },
        { name = "MONGO_INITDB_DATABASE",      value = "transaction_db" }
      ]

      mountPoints = [
        {
          sourceVolume  = "mongodb_data"
          containerPath = "/data/db"
          readOnly      = false
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "mongosh --quiet --eval 'db.runCommand({ping:1}).ok' 2>/dev/null | grep -q 1 || exit 1"]
        interval    = 15
        timeout     = 10
        retries     = 5
        startPeriod = 30
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs-mongo"
        }
      }
    }
  ])

  tags = { Name = "${var.app_name}_mongodb_task_def" }
}

# ==========================================
# App ECS Service
# ==========================================
resource "aws_ecs_service" "app" {
  name            = "${var.app_name}_service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "${var.app_name}-app"
    container_port   = 8080
  }

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.ecs_task_sqs,
    aws_iam_role_policy_attachment.ecs_task_secretsmanager,
    aws_iam_role_policy_attachment.ecs_task_cloudwatch,
    aws_iam_role_policy_attachment.ecs_task_s3,
    aws_iam_role_policy_attachment.ecs_task_xray,
  ]

  tags = { Name = "${var.app_name}_service" }
}

# ==========================================
# MongoDB ECS Service
# ==========================================
resource "aws_ecs_service" "mongodb" {
  name            = "${var.app_name}_mongodb_service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.mongodb.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # Zero-downtime não se aplica ao MongoDB — ele não pode ter 
  # duas tasks simultâneas pois o EFS não suporta lock concorrente
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.mongodb.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn   = aws_service_discovery_service.mongodb.arn
    container_name = "mongodb"
  }

  tags = { Name = "${var.app_name}_mongodb_service" }
}
