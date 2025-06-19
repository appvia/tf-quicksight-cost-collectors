# Create Lambda function for processing SQL files and executing Athena queries
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = var.lambda_zip_output_path
}

resource "aws_lambda_function" "athena_view_creator" {
  function_name = "athena-view-creator"
  description   = "Executes Athena queries from SQL files stored in S3"
  role          = aws_iam_role.lambda_role.arn
  handler       = "collector.handler"
  runtime       = "python3.12"
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  environment {
    variables = {
      ATHENA_WORKGROUP = var.athena_workgroup
      ATHENA_DATABASE  = var.athena_database
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "Athena View Creator"
    }
  )
}

# Create CloudWatch log group for Lambda logs
resource "aws_cloudwatch_log_group" "lambda_logs" {
  count = var.create_lambda_log_group ? 1 : 0

  name              = "/aws/lambda/athena-view-creator"
  retention_in_days = var.log_retention_in_days

  tags = var.tags
}
