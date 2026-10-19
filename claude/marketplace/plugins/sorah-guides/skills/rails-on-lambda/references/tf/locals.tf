locals {
  default_environments = {
    LANG                     = "C.UTF-8"
    RACK_ENV                 = var.environment
    RAILS_ENV                = var.environment
    RAILS_LOG_TO_STDOUT      = "1"
    RAILS_SERVE_STATIC_FILES = "1"
    # An execution environment serves one request at a time.
    WEB_CONCURRENCY   = "0"
    RAILS_MAX_THREADS = "2"

    JOB_ADAPTER     = "lambdakiq"
    LAMBDAKIQ_QUEUE = aws_sqs_queue.lambdakiq.name
  }

  default_secrets = {
    CLOUDFRONT_VERIFY = aws_ssm_parameter.cloudfront_verify.arn
  }
  secrets = merge(local.default_secrets, var.secrets)

  # Resolved into ENV by config/lambda_boot.rb.
  secret_loader_environments = {
    for key, arn in local.secrets :
    "SSM_SECRET__${key}" => arn
  }

  environments = merge(local.default_environments, local.secret_loader_environments, var.environments)
}
