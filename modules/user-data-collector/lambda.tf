data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = var.lambda_zip_output_path
}

resource "aws_lambda_function" "collector" {
  function_name = "user-data-collector"
  handler       = "collector.handler"
  runtime       = "python3.12"
  role          = aws_iam_role.collector.arn

  timeout = 120
  environment {
    variables = {
      DYNAMODB_TABLE_NAME                 = aws_dynamodb_table.user_data.name
      GITLAB_BASE_URL                     = var.gitlab_base_url  
      GITLAB_PROJECT_ID                   = var.gitlab_project_id
      GITLAB_ACCESS_TOKEN_SECRET_NAME     = var.gitlab_access_token_secret_name
      GITLAB_FILE_PATH                    = var.gitlab_file_path
      GITLAB_REF                          = var.gitlab_ref
      GITLAB_IGNORE_SSL                   = var.gitlab_ignore_ssl
      MOCK_MODE                           = var.mock_mode
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
    aws_iam_role_policy_attachment.collector,
    aws_cloudwatch_log_group.collector,
  ]
}

resource "aws_cloudwatch_log_group" "collector" {
  name              = "/aws/lambda/user-data-collector"
  retention_in_days = var.log_retention_in_days
}

data "aws_iam_policy_document" "collector" {
  statement {
    actions   = ["dynamodb:PutItem", "dynamodb:GetItem"]
    resources = [aws_dynamodb_table.user_data.arn]
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      aws_cloudwatch_log_group.collector.arn,
      "${aws_cloudwatch_log_group.collector.arn}:*"
    ]
  }

  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:*:*:secret:${var.gitlab_access_token_secret_name}*"]
  }
}

resource "aws_iam_policy" "collector" {
  name        = "user-data-collector"
  description = "Policy for the user data collector"
  policy      = data.aws_iam_policy_document.collector.json
}

resource "aws_iam_role_policy_attachment" "collector" {
  role       = aws_iam_role.collector.name
  policy_arn = aws_iam_policy.collector.arn
}

# Attach the AWS managed policy for VPC access (only if VPC config is provided)
resource "aws_iam_role_policy_attachment" "collector_vpc_access" {
  count      = var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.collector.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role" "collector" {
  name               = "user-data-collector"
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
