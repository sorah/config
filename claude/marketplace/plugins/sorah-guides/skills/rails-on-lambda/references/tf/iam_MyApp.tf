resource "aws_iam_role" "MyApp" {
  name               = "MyApp"
  description        = "myapp tf/iam_MyApp.tf"
  assume_role_policy = data.aws_iam_policy_document.MyApp-trust.json
}

data "aws_iam_policy_document" "MyApp-trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "MyApp-AWSLambdaBasicExecutionRole" {
  role       = aws_iam_role.MyApp.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "MyApp" {
  role   = aws_iam_role.MyApp.name
  policy = data.aws_iam_policy_document.MyApp.json
}

data "aws_iam_policy_document" "MyApp" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
    ]
    resources = [aws_sqs_queue.lambdakiq.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameters"]
    resources = values(local.secrets)
  }
  # Add kms:Decrypt on the key when parameters use a customer managed key.
}

data "aws_iam_policy_document" "GhaMyAppDeploy" {
  statement {
    effect = "Allow"
    actions = [
      "lambda:UpdateFunctionCode",
      "lambda:GetFunctionConfiguration",
    ]
    resources = [for v in aws_lambda_function.app : v.arn]
  }
  statement {
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.app["runner"].arn]
  }
  # Lambda checks the caller can read the image, and grants itself access through the repository policy.
  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:SetRepositoryPolicy",
      "ecr:GetRepositoryPolicy",
    ]
    resources = [aws_ecr_repository.app.arn]
  }
}
