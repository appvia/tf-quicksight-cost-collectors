# IAM role for Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "athena-view-creator-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM policy for Lambda function
resource "aws_iam_policy" "lambda_policy" {
  name        = "athena-view-creator-lambda-policy"
  description = "Policy for Athena View Creator Lambda function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # CloudWatch Logs permissions
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/athena-view-creator:*"
      },
      # S3 permissions
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Effect = "Allow"
        Resource = [
          module.s3_bucket_sql_files.s3_bucket_arn,
          "${module.s3_bucket_sql_files.s3_bucket_arn}/*"
        ]
      },
      # Athena permissions
      {
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:GetWorkGroup",
          "athena:BatchGetQueryExecution"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      # Glue permissions (needed for Athena to access the data catalog)
      {
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:GetTables",
          "glue:CreateDatabase",
          "glue:DeleteTable"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      # S3 permissions for Athena query results
      {
        Action = [
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::${var.athena_results_bucket_name}",
          "arn:aws:s3:::${var.athena_results_bucket_name}/*"
        ]
      }
    ]
  })

  tags = var.tags
}

# Attach policy to IAM role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Permission for S3 to invoke Lambda
resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.athena_view_creator.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = module.s3_bucket_sql_files.s3_bucket_arn
}
