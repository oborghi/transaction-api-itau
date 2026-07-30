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
      # Linha 1: ECS CPU & Memory
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", { stat = "Average", label = "CPU %" }],
            [".", "MemoryUtilization", { stat = "Average", label = "Memory %" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS CPU & Memory Utilization"
          width  = 12
          height = 6
        }
      },
      # Linha 1: ALB Request Count
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", { stat = "Sum", label = "Requests" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "ALB Request Count"
          width  = 12
          height = 6
        }
      },
      # Linha 2: Custom Metrics (TransactionAPI)
      {
        type = "metric"
        properties = {
          metrics = [
            ["TransactionAPI", "TransactionsProcessed", { stat = "Sum", label = "Transactions" }],
            [".", "TransactionSuccessRate", { stat = "Average", label = "Success Rate %" }],
            [".", "AuthorizationLatency", { stat = "Average", label = "Latency (s)" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Transaction API - Business Metrics"
          width  = 12
          height = 6
        }
      },
      # Linha 2: SQS Queue Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", { stat = "Average", label = "Visible" }],
            [".", "ApproximateNumberOfMessagesNotVisible", { stat = "Average", label = "In Flight" }],
            [".", "NumberOfMessagesDeleted", { stat = "Sum", label = "Deleted" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "SQS Queue - Messages"
          width  = 12
          height = 6
        }
      },
      # Linha 3: Application Logs
      {
        type = "log"
        properties = {
          query  = "SOURCE '/ecs/${var.app_name}' | fields @timestamp, @message\n| sort @timestamp desc\n| limit 50"
          region = var.aws_region
          title  = "📋 Application Logs (last 50)"
          width  = 24
          height = 12
        }
      },
      # Linha 4: X-Ray Traces (quick link + info)
      {
        type = "text"
        properties = {
          markdown = "## 🚀 X-Ray Distributed Tracing\n\n### Spans disponíveis:\n- `transaction.authorize` - Autorização de transação\n- `mongodb.query` - Consultas MongoDB\n- `sqs.consume` - Consumo de mensagens SQS\n- `http.server.request` - Requisições HTTP\n\n### Links:\n- [X-Ray Console](https://${var.aws_region}.console.aws.amazon.com/xray/home?region=${var.aws_region}#/traces)\n- [Service Map](https://${var.aws_region}.console.aws.amazon.com/xray/home?region=${var.aws_region}#/service-map)"
          width  = 24
          height = 6
        }
      }
    ]
  })
}
