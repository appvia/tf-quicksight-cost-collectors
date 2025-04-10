# KMS key for encryption
resource "aws_kms_key" "cost_analysis" {
  description             = "KMS key for cost analysis infrastructure"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = var.tags
}

resource "aws_kms_alias" "cost_analysis" {
  name          = "alias/${var.key_alias}"
  target_key_id = aws_kms_key.cost_analysis.key_id
}

# IAM policy document for KMS key usage
data "aws_iam_policy_document" "kms_key_policy" {
  # Root account access
  statement {
    effect = "Allow"
    actions = [
      "kms:*"
    ]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  # Creator access
  statement {
    effect = "Allow"
    actions = [
      "kms:*"
    ]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.arn]
    }
  }

  # Athena access
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:ReEncryptFrom",
      "kms:ReEncryptTo"
    ]
    resources = [aws_kms_key.cost_analysis.arn]
    principals {
      type        = "Service"
      identifiers = ["athena.amazonaws.com"]
    }
  }

  # S3 access
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:ReEncryptFrom",
      "kms:ReEncryptTo"
    ]
    resources = [aws_kms_key.cost_analysis.arn]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

resource "aws_kms_key_policy" "cost_analysis" {
  key_id = aws_kms_key.cost_analysis.id
  policy = data.aws_iam_policy_document.kms_key_policy.json
}

# Athena Workgroup
resource "aws_athena_workgroup" "cost_analysis" {
  name = var.workgroup_name

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${var.results_bucket_name}/athena-results/"

      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_arn       = aws_kms_key.cost_analysis.arn
      }
    }
  }

  tags = var.tags
}

# Athena Database
resource "aws_athena_database" "cost_analysis" {
  name   = var.database_name
  bucket = var.results_bucket_name

  encryption_configuration {
    encryption_option = "SSE_KMS"
    kms_key           = aws_kms_key.cost_analysis.arn
  }
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
