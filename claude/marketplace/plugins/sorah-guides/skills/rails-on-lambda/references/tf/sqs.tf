resource "aws_sqs_queue" "lambdakiq-dlq" {
  name                      = "myapp-lambdakiq-dlq-${var.name}"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "lambdakiq" {
  name = "myapp-lambdakiq-${var.name}"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.lambdakiq-dlq.arn
    # Lambdakiq's 12 retries plus the first attempt.
    maxReceiveCount = 13
  })

  # Must exceed the lambdakiq function's timeout.
  visibility_timeout_seconds = 301
}
