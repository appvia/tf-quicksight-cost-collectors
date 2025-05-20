# Create S3 bucket for storing SQL files using the standard S3 module
module "s3_bucket_sql_files" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.6.0"

  bucket           = local.bucket_name
  force_destroy    = true # Allow terraform to delete the bucket even if it contains files
  object_ownership = "BucketOwnerEnforced"
  attach_policy    = true # Attach the policy below
  policy           = data.aws_iam_policy_document.sql_files_policy.json

  # Block public access
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  # Enable server-side encryption
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "Athena View SQL Files"
    }
  )
}

# Define the bucket policy
data "aws_iam_policy_document" "sql_files_policy" {
  # Allow Lambda to access the SQL files
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      module.s3_bucket_sql_files.s3_bucket_arn,
      "${module.s3_bucket_sql_files.s3_bucket_arn}/*"
    ]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.lambda_role.arn]
    }
  }
}

# Upload SQL files from the specified directory to the bucket (paths relative to sql_directory_path are preserved)
resource "aws_s3_object" "sql_files" {
  for_each = fileset(var.sql_directory_path, "**/*.sql")

  bucket       = module.s3_bucket_sql_files.s3_bucket_id
  key          = each.value
  source       = "${var.sql_directory_path}/${each.value}"
  content_type = "text/plain"
  etag         = filemd5("${var.sql_directory_path}/${each.value}")

  tags = merge(
    var.tags,
    {
      Name = each.value
    }
  )
}

# Configure S3 event notification to trigger Lambda when files are created or updated
resource "aws_s3_bucket_notification" "bucket_notification" {
  count  = var.enable_notification ? 1 : 0
  bucket = module.s3_bucket_sql_files.s3_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.athena_view_creator.arn
    events              = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
    filter_suffix       = ".sql"
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}
