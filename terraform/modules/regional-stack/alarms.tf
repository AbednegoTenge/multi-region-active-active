
resource "aws_sns_topic" "alerts" {
    name = "${local.region}-alerts"
    tags = local.app_tags
}

resource "aws_sns_topic_subscription" "alerts_email" {
    topic_arn = aws_sns_topic.alerts.arn
    protocol  = "email"
    endpoint  = var.alerts_email
}

resource "aws_cloudwatch_metric_alarm" "unhealthy" {
    alarm_name          = "${local.region}-unhealthy"
    namespace          = "AWS/ApplicationELB"
    metric_name        = "UnHealthyHostCount"
    statistic          = "Maximum"
    period             = 60
    evaluation_periods = 1
    threshold          = 1
    comparison_operator = "GreaterThanOrEqualToThreshold"
    dimensions = {
        TargetGroup = aws_lb_target_group.this.arn_suffix
        LoadBalancer = aws_lb.this.arn_suffix
    }
    alarm_actions = [aws_sns_topic.alerts.arn]
    ok_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "stale" {
    alarm_name = "${local.region}-stale-data"
    namespace = "MultiRegion"
    metric_name = "StaleSeconds"
    statistic = "Maximum"
    period = 60
    evaluation_periods = 1
    threshold = 30
    comparison_operator = "GreaterThanThreshold"
    treat_missing_data = "notBreaching"
    alarm_actions = [aws_sns_topic.alerts.arn]
    ok_actions = [aws_sns_topic.alerts.arn]
    dimensions = {
        Region = local.region
    }
}
