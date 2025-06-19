data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = var.lambda_zip_output_path
}

resource "aws_lambda_function" "usage_collector" {
  function_name = "sonarqube-usage-collector"
  handler       = "collector.handler"
  runtime       = "python3.12"
  role          = aws_iam_role.usage_collector.arn

  timeout = 120
  environment {
    variables = {
      # SONARQUBE_DOMAIN            = var.sonarqube_domain
      # SONARQUBE_PORT              = var.sonarqube_port
      # SONARQUBE_SCHEME            = var.sonarqube_scheme
      # SONARQUBE_TOKEN_SECRET_NAME = var.sonarqube_token_secret_name
      OUTPUT_BUCKET = var.usage_data_bucket_name
      MOCK_MODE     = var.mock_mode
    }
  }
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.usage_collector,
    aws_cloudwatch_log_group.usage_collector,
  ]
}

resource "aws_cloudwatch_log_group" "usage_collector" {
  name              = "/aws/lambda/sonarqube-usage-collector"
  retention_in_days = var.log_retention_in_days
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

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      aws_cloudwatch_log_group.usage_collector.arn,
      "${aws_cloudwatch_log_group.usage_collector.arn}:*"
    ]
  }
}

resource "aws_iam_policy" "usage_collector" {
  name        = "sonarqube-usage-collector"
  description = "Policy for the sonarqube usage collector"
  policy      = data.aws_iam_policy_document.usage_collector.json
}

resource "aws_iam_role_policy_attachment" "usage_collector" {
  role       = aws_iam_role.usage_collector.name
  policy_arn = aws_iam_policy.usage_collector.arn
}

# Attach the AWS managed policy for VPC access (only if VPC config is provided)
resource "aws_iam_role_policy_attachment" "usage_collector_vpc_access" {
  count      = var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.usage_collector.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role" "usage_collector" {
  name               = "sonarqube-usage-collector"
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

