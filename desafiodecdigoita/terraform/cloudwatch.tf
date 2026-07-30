resource "aws_cloudwatch_log_group" "app" {
  name              = "/eks/${var.app_name}"
  retention_in_days = 30

  tags = { Name = "${var.app_name}_logs" }
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.app_name}_high_cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU utilization is too high"
  alarm_actions       = []

  dimensions = {
    ClusterName = aws_eks_cluster.main.name
  }

  tags = { Name = "${var.app_name}_high_cpu" }
}

resource "aws_cloudwatch_metric_alarm" "high_memory" {
  alarm_name          = "${var.app_name}_high_memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Memory utilization is too high"
  alarm_actions       = []

  dimensions = {
    ClusterName = aws_eks_cluster.main.name
  }

  tags = { Name = "${var.app_name}_high_memory" }
}