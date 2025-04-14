module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.6.0"

  bucket           = var.results_bucket_name
  attach_policy    = true
  force_destroy    = false
  object_ownership = "BucketOwnerEnforced"
  policy           = data.aws_iam_policy_document.athena_policy.json

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = aws_kms_key.cost_analysis.arn
      }
    }
  }
}

locals {
  quicksight_default_role = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/service-role/aws-quicksight-service-role-v0"
}

# bucket policy to allow athena and quicksight to access the bucket
data "aws_iam_policy_document" "athena_policy" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${module.s3_bucket.s3_bucket_arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["athena.amazonaws.com"]
    }
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["${module.s3_bucket.s3_bucket_arn}"]
    principals {
      type        = "Service"
      identifiers = ["athena.amazonaws.com"]
    }
  }
  # Add QuickSight permissions
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:GetBucketLocation"
    ]
    resources = [
      "${module.s3_bucket.s3_bucket_arn}",
      "${module.s3_bucket.s3_bucket_arn}/*"
    ]
    principals {
      type        = "AWS"
      identifiers = [local.quicksight_default_role]
    }
  }
}

# Get current region
data "aws_region" "current" {}
