resource "aws_cloudwatch_log_subscription_filter" "default" {
  name            = var.name
  log_group_name  = var.log_group_name
  filter_pattern  = var.filter_pattern
  destination_arn = var.destination_lambda_arn
}

resource "aws_lambda_permission" "allow_cloudwatch_logs" {
  statement_id  = "AllowCloudWatchLogs-${var.name}"
  action        = "lambda:InvokeFunction"
  function_name = var.destination_lambda_arn
  principal     = "logs.amazonaws.com"
  source_arn    = "${var.log_group_arn}:*"
}
