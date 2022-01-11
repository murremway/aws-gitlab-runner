resource "aws_cloudwatch_log_group" "log_group" {
  name              = "gitlab-runner-supervisor-${var.service_name}"
  retention_in_days = var.log_retention

  tags = merge(local.service_tags, { "Name" : "gitlab-runner-supervisor-${var.service_name}" })
}

