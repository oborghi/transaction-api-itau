# ==========================================
# AWS X-Ray Configuration
# ==========================================
# Sampling rules to control tracing costs while ensuring
# critical financial flows are traced 100%.
# Free Tier: 100K traces/month
# ==========================================

# ──────────────────────────────────────────
# X-Ray Sampling Rules
# ──────────────────────────────────────────
# Priority: lower number = higher priority
# Rules are evaluated in order of priority
# ──────────────────────────────────────────

# Rule 1: Transaction authorization (CRITICAL - trace every transaction)
# Each transaction is real money movement - 100% sampling required
resource "aws_xray_sampling_rule" "transactions" {
  rule_name      = "${var.app_name}_transactions"
  priority       = 1000
  version        = 1
  reservoir_size = 100
  fixed_rate     = 1.0  # 100% sampling for money movements
  resource_arn   = "*"

  host           = "*"
  http_method    = "POST"
  url_path       = "/api/v1/transactions/*"
  service_name   = var.app_name
  service_type   = "*"

  attributes = {
    "environment" = var.environment
  }

  tags = { Name = "${var.app_name}_xray_rule_transactions" }
}

# Rule 2: Auth token (HIGH - 10% sampling sufficient)
resource "aws_xray_sampling_rule" "auth" {
  rule_name      = "${var.app_name}_auth"
  priority       = 2000
  version        = 1
  reservoir_size = 10
  fixed_rate     = 0.1  # 10% sampling
  resource_arn   = "*"

  host           = "*"
  http_method    = "POST"
  url_path       = "/api/v1/auth/token"
  service_name   = var.app_name
  service_type   = "*"

  attributes = {
    "environment" = var.environment
  }

  tags = { Name = "${var.app_name}_xray_rule_auth" }
}

# Rule 3: Health/Actuator endpoints (LOW - 1% sampling)
resource "aws_xray_sampling_rule" "health" {
  rule_name      = "${var.app_name}_health"
  priority       = 3000
  version        = 1
  reservoir_size = 5
  fixed_rate     = 0.01  # 1% sampling
  resource_arn   = "*"

  host           = "*"
  http_method    = "*"
  url_path       = "/actuator/*"
  service_name   = var.app_name
  service_type   = "*"

  attributes = {
    "environment" = var.environment
  }

  tags = { Name = "${var.app_name}_xray_rule_health" }
}

# Rule 4: Default fallback (5% sampling)
# Applies to any request not matched by above rules
resource "aws_xray_sampling_rule" "default" {
  rule_name      = "${var.app_name}_default"
  priority       = 9999
  version        = 1
  reservoir_size = 5
  fixed_rate     = 0.05  # 5% sampling
  resource_arn   = "*"

  host           = "*"
  http_method    = "*"
  url_path       = "*"
  service_name   = "*"
  service_type   = "*"

  attributes = {
    "environment" = var.environment
  }

  tags = { Name = "${var.app_name}_xray_rule_default" }
}

# ──────────────────────────────────────────
# SLO Metrics (via CloudWatch Metric Filters)
# ──────────────────────────────────────────
# These metrics are derived from X-Ray traces and
# CloudWatch Logs to track Service Level Objectives
# ──────────────────────────────────────────

# SLO-1: Transaction Authorization Latency (P95 < 1s)
# Tracks latency of the critical transaction flow
resource "aws_cloudwatch_metric_alarm" "slo_transaction_latency" {
  alarm_name          = "${var.app_name}_slo_transaction_latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "transaction.authorization.latency.avg"
  namespace           = "TransactionAPI"
  period              = 300
  extended_statistic  = "p95"
  threshold           = 1000  # 1 second in milliseconds
  alarm_description   = "SLO BREACH: P95 transaction authorization latency exceeded 1s (target: 99.9% < 1s)"
  alarm_actions       = []

  dimensions = {
    type   = "CREDIT"
    status = "SUCCEEDED"
  }

  tags = {
    Name     = "${var.app_name}_slo_transaction_latency"
    SLO      = "SLO-1"
    Severity = "CRITICAL"
  }
}

# SLO-2: Transaction Success Rate (99.99%)
# Tracks error rate of transaction authorizations
resource "aws_cloudwatch_metric_alarm" "slo_transaction_error_rate" {
  alarm_name          = "${var.app_name}_slo_transaction_error_rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "transaction.total.count"
  namespace           = "TransactionAPI"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "SLO BREACH: Transaction error rate exceeded 0.1% (target: 99.99% success rate)"
  treat_missing_data  = "notBreaching"
  alarm_actions       = []

  dimensions = {
    type   = "DEBIT"
    status = "FAILED"
  }

  tags = {
    Name     = "${var.app_name}_slo_transaction_error_rate"
    SLO      = "SLO-2"
    Severity = "CRITICAL"
  }
}

# SLO-3: SQS Processing Health (DLQ > 0 = breach)
# Alerts when messages are being sent to DLQ
resource "aws_cloudwatch_metric_alarm" "slo_sqs_dlq" {
  alarm_name          = "${var.app_name}_slo_sqs_dlq"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "SLO BREACH: Messages detected in DLQ (target: 99.9% messages processed without DLQ)"
  treat_missing_data  = "notBreaching"
  alarm_actions       = []

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }

  tags = {
    Name     = "${var.app_name}_slo_sqs_dlq"
    SLO      = "SLO-3"
    Severity = "HIGH"
  }
}

# SLO-4: API Availability (ALB 5xx rate)
# Tracks HTTP 5xx errors from ALB
resource "aws_cloudwatch_metric_alarm" "slo_api_availability" {
  alarm_name          = "${var.app_name}_slo_api_availability"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "SLO BREACH: HTTP 5xx errors detected on ALB (target: 99.9% availability)"
  treat_missing_data  = "notBreaching"
  alarm_actions       = []

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = {
    Name     = "${var.app_name}_slo_api_availability"
    SLO      = "SLO-4"
    Severity = "CRITICAL"
  }
}

# SLO-5: SQS Consumer Failure Rate
# Alerts when SQS messages are failing to process
resource "aws_cloudwatch_metric_alarm" "slo_sqs_consumer_failures" {
  alarm_name          = "${var.app_name}_slo_sqs_consumer_failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "sqs.messages.failed"
  namespace           = "TransactionAPI"
  period              = 300
  statistic           = "Sum"
  threshold           = 5  # More than 5 failures in 10 min
  alarm_description   = "SLO BREACH: High SQS consumer failure rate (target: 99.9% successful consumption)"
  treat_missing_data  = "notBreaching"
  alarm_actions       = []

  tags = {
    Name     = "${var.app_name}_slo_sqs_consumer_failures"
    SLO      = "SLO-5"
    Severity = "HIGH"
  }
}