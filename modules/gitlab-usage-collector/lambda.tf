resource "aws_lambda_function" "usage_collector" {
  function_name = "gitlab-usage-collector"
  handler       = "lambda.handler"
  runtime       = "python3.12"
  role          = aws_iam_role.usage_collector.arn

  timeout = 120
  environment {
    variables = {
      # gitlab_DOMAIN            = var.gitlab_domain
      # gitlab_PORT              = var.gitlab_port
      # gitlab_SCHEME            = var.gitlab_scheme
      # gitlab_TOKEN_SECRET_NAME = var.gitlab_token_secret_name
      OUTPUT_BUCKET = var.usage_data_bucket_name
      MOCK_MODE     = var.mock_mode
    }
  }
  filename         = "${path.module}/lambda/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/lambda.zip")
}

data "aws_iam_policy_document" "usage_collector" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${var.usage_data_bucket_name}/*"]
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.usage_data_bucket_name}"]
  }

  statement {
    actions   = ["kms:Encrypt"]
    resources = [var.usage_data_bucket_key_arn]
  }
}

resource "aws_iam_policy" "usage_collector" {
  name        = "gitlab-usage-collector"
  description = "Policy for the gitlab usage collector"
  policy      = data.aws_iam_policy_document.usage_collector.json
}

resource "aws_iam_role_policy_attachment" "usage_collector" {
  role       = aws_iam_role.usage_collector.name
  policy_arn = aws_iam_policy.usage_collector.arn
}

resource "aws_iam_role" "usage_collector" {
  name               = "gitlab-usage-collector"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}
