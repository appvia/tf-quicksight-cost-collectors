# Athena Workgroup
resource "aws_athena_workgroup" "cost_analysis" {
  name = var.workgroup_name

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${var.results_bucket_name}/athena-results/"
    }
  }

  tags = var.tags
}

# Athena Database
resource "aws_athena_database" "cost_analysis" {
  name   = var.database_name
  bucket = var.results_bucket_name
}

# IAM policy document for Athena assume role
data "aws_iam_policy_document" "athena_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["athena.amazonaws.com"]
    }
  }
}

# IAM role for Athena
resource "aws_iam_role" "athena_role" {
  name               = var.athena_role_name
  assume_role_policy = data.aws_iam_policy_document.athena_assume_role.json
  tags               = var.tags
}

# IAM policy document for Athena S3 access
data "aws_iam_policy_document" "athena_s3_access" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::${var.results_bucket_name}",
      "arn:aws:s3:::${var.results_bucket_name}/*"
    ]
  }
}

# IAM policy for Athena to access S3
resource "aws_iam_role_policy" "athena_s3_access" {
  name   = "athena_s3_access"
  role   = aws_iam_role.athena_role.id
  policy = data.aws_iam_policy_document.athena_s3_access.json
}
