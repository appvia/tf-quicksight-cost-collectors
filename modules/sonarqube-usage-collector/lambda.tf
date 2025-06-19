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
      SONARQUBE_DOMAIN            = var.sonarqube_domain
      SONARQUBE_PORT              = var.sonarqube_port
      SONARQUBE_SCHEME            = var.sonarqube_scheme
      SONARQUBE_TOKEN_SECRET_NAME = var.sonarqube_token_secret_name
      ATHENA_TABLE_NAME           = var.athena_table_name
      OUTPUT_BUCKET               = var.usage_data_bucket_name
      MOCK_MODE                   = var.mock_mode
    }
  }
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids = vpc_config.value.subnet_ids
      security_group_ids = concat(
        vpc_config.value.security_group_ids,
        [aws_security_group.lambda_sg[0].id]
      )
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

  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:*:*:secret:${var.sonarqube_token_secret_name}*"]
  }

  statement {
    actions = [
      "athena:StartQueryExecution",
      "athena:GetQueryExecution",
      "athena:GetQueryResults"
    ]
    resources = [
      "arn:aws:athena:*:*:workgroup/${var.athena_workgroup_name}",
      "arn:aws:athena:*:*:datacatalog/*"
    ]
  }

  statement {
    actions = [
      "glue:GetDatabase"
    ]
    resources = [
      "arn:aws:glue:*:*:catalog",
      "arn:aws:glue:*:*:database/${var.athena_database_name}"
    ]
  }

  statement {
    actions = [
      "glue:GetTable"
    ]
    resources = [
      "arn:aws:glue:*:*:table/${var.athena_database_name}/${var.athena_table_name}"
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

# Security group for Lambda function when running in VPC mode
resource "aws_security_group" "lambda_sg" {
  count       = var.vpc_config != null ? 1 : 0
  name_prefix = "sonarqube-usage-collector-lambda-"
  description = "Security group for SonarQube usage collector Lambda function"
  vpc_id      = data.aws_vpc.this[0].id

  tags = merge(var.tags, {
    Name = "sonarqube-usage-collector-lambda-sg"
  })
}

# Configurable egress rules for Lambda function
resource "aws_vpc_security_group_egress_rule" "lambda_egress" {
  count = var.vpc_config != null ? length(var.lambda_egress_rules) : 0

  security_group_id = aws_security_group.lambda_sg[0].id
  
  description = var.lambda_egress_rules[count.index].description
  ip_protocol = var.lambda_egress_rules[count.index].ip_protocol
  from_port   = var.lambda_egress_rules[count.index].from_port
  to_port     = var.lambda_egress_rules[count.index].to_port
  cidr_ipv4   = var.lambda_egress_rules[count.index].cidr_ipv4
}

