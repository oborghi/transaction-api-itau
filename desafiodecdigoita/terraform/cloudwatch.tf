# ==========================================
# CloudWatch Logs + Metrics + Alarms
# ==========================================

# Log group is already defined in ecs.tf (aws_cloudwatch_log_group.ecs)
# This file adds CloudWatch dashboards and alarms

# CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.app_name}_high_cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU utilization is above 80%"
  alarm_actions       = []

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }

  tags = { Name = "${var.app_name}_high_cpu" }
}

# Memory Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "high_memory" {
  alarm_name          = "${var.app_name}_high_memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Memory utilization is above 80%"
  alarm_actions       = []

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }

  tags = { Name = "${var.app_name}_high_memory" }
}

# CloudWatch Dashboard - Overview
resource "aws_cloudwatch_dashboard" "overview" {
  dashboard_name = "${var.app_name}_overview"

  dashboard_body = jsonencode({
    widgets = [
      # ──────────────────────────────────────
      # Linha 1: ECS CPU & Memory Utilization
      # ──────────────────────────────────────
      {
        type = "metric"
        properties = {
          metrics = [
            [
              "AWS/ECS",
              "CPUUtilization",
              "ClusterName",
              aws_ecs_cluster.main.name,
              "ServiceName",
              aws_ecs_service.app.name
            ],
            [
              "AWS/ECS",
              "MemoryUtilization",
              "ClusterName",
              aws_ecs_cluster.main.name,
              "ServiceName",
              aws_ecs_service.app.name
            ]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS CPU & Memory Utilization"
          width  = 12
          height = 6
        }
      },
      # ──────────────────────────────────────
      # Linha 1: ALB Request Count
      # ──────────────────────────────────────
      {
        type = "metric"
        properties = {
          metrics = [
            [
              "AWS/ApplicationELB",
              "RequestCount",
              "LoadBalancer",
              aws_lb.main.arn_suffix
            ]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "ALB Request Count"
          width  = 12
          height = 6
        }
      },
      # ──────────────────────────────────────
      # Linha 2: Custom Metrics (Micrometer → TransactionAPI namespace)
      # ──────────────────────────────────────
      {
        type = "metric"
        properties = {
          metrics = [
            ["TransactionAPI", "transaction.total.count", "type", "CREDIT", "status", "SUCCEEDED", { stat = "Sum", label = "Credit Transactions" }],
            ["TransactionAPI", "transaction.total.count", "type", "DEBIT", "status", "SUCCEEDED", { stat = "Sum", label = "Debit Transactions" }],
            ["TransactionAPI", "transaction.total.count", "status", "FAILED", { stat = "Sum", label = "Failed Transactions" }],
            ["TransactionAPI", "sqs.messages.consumed.count", { stat = "Sum", label = "SQS Consumed" }],
            ["TransactionAPI", "sqs.messages.failed.count", { stat = "Sum", label = "SQS Failed" }],
            ["TransactionAPI", "transaction.authorization.latency.avg", { stat = "Average", label = "Avg Latency (s)" }],
            ["TransactionAPI", "transaction.authorization.latency.max", { stat = "Maximum", label = "Max Latency (s)" }],
            ["TransactionAPI", "account.balance.avg.value", { stat = "Average", label = "Avg Balance (BRL)" }],
            ["TransactionAPI", "account.total.value", { stat = "Average", label = "Active Accounts" }]
          ]
          period = 300
          region = var.aws_region
          title  = "Transaction API - Business Metrics"
          width  = 12
          height = 6
        }
      },
      # ──────────────────────────────────────
      # Linha 2: SQS Queue - Messages
      # ──────────────────────────────────────
      {
        type = "metric"
        properties = {
          metrics = [
            [
              "AWS/SQS",
              "ApproximateNumberOfMessagesVisible",
              "QueueName",
              aws_sqs_queue.main.name
            ],
            [
              "AWS/SQS",
              "ApproximateNumberOfMessagesNotVisible",
              "QueueName",
              aws_sqs_queue.main.name
            ],
            [
              "AWS/SQS",
              "NumberOfMessagesDeleted",
              "QueueName",
              aws_sqs_queue.main.name
            ]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "SQS Queue - Messages"
          width  = 12
          height = 6
        }
      },
      # ──────────────────────────────────────
      # Linha 3: SLO Compliance Overview
      # ──────────────────────────────────────
      {
        type = "metric"
        properties = {
          metrics = [
            ["TransactionAPI", "transaction.authorization.latency.percentile.value", "phi", "0.95", { stat = "Average", label = "SLO-1: P95 Latency (s)", color = "#ff9900" }],
            ["TransactionAPI", "transaction.total.count", "status", "FAILED", { stat = "Sum", label = "SLO-2: Failed Transactions", color = "#d13212" }],
            ["TransactionAPI", "sqs.messages.failed.count", { stat = "Sum", label = "SLO-5: SQS Failures", color = "#e6b81e" }]
          ]
          period = 300
          region = var.aws_region
          title  = "SLO Compliance - Business Metrics"
          width  = 12
          height = 6
        }
      },
      # ──────────────────────────────────────
      # Linha 3: SLO Alarms Status
      # ──────────────────────────────────────
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Sum", label = "SLO-4: ALB 5xx Errors", color = "#d13212" }],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.dlq.name, { stat = "Sum", label = "SLO-3: DLQ Messages", color = "#e6b81e" }]
          ]
          period = 300
          region = var.aws_region
          title  = "SLO Alarms - Infrastructure"
          width  = 12
          height = 6
        }
      },
      # ──────────────────────────────────────
      # Linha 4: Application Logs
      # ──────────────────────────────────────
      {
        type = "log"
        properties = {
          query  = "SOURCE '/ecs/${var.app_name}' | fields @timestamp, @message | sort @timestamp desc | limit 50"
          region = var.aws_region
          title  = "Application Logs (last 50)"
          width  = 24
          height = 12
        }
      }
    ]
  })
}