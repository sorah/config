resource "aws_lambda_function" "app" {
  for_each = {
    web = {
      handler     = "config/lambda_rack.LambdaRackApp.handle"
      memory_size = 1024
      timeout     = 60 # CloudFront's default origin_read_timeout limit
    }
    lambdakiq = {
      handler     = "config/environment.Lambdakiq.cmd"
      memory_size = 1024
      timeout     = 300
    }
    runner = {
      handler     = "config/lambda_runner.CommandRunner.handle"
      memory_size = 2048
      timeout     = 900
    }
  }

  function_name = "myapp-${each.key}-${var.name}"

  package_type  = "Image"
  architectures = ["x86_64"]
  image_uri     = var.initial_image_uri

  image_config {
    entry_point = ["/lambda_entrypoint.sh"]
  }

  role = aws_iam_role.MyApp.arn

  memory_size = each.value.memory_size
  timeout     = each.value.timeout

  environment {
    variables = merge(local.environments, {
      APP_HANDLER = each.value.handler # exported as $_HANDLER by config/lambda_entrypoint.sh
    })
  }

  tags = {
    Component = each.key
  }

  lifecycle {
    # Deployed by CI with UpdateFunctionCode.
    ignore_changes = [
      image_uri,
    ]
  }
}

resource "aws_lambda_function_url" "app" {
  function_name      = aws_lambda_function.app["web"].function_name
  authorization_type = "NONE"
}

resource "aws_lambda_event_source_mapping" "lambdakiq" {
  event_source_arn = aws_sqs_queue.lambdakiq.arn
  function_name    = aws_lambda_function.app["lambdakiq"].arn
  batch_size       = 1

  # Lambdakiq reports retries and failures per message.
  function_response_types = ["ReportBatchItemFailures"]
}
