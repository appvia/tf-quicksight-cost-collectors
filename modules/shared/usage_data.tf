
# s3 bucket for usage data
module "s3_bucket_usage_data" {
  count   = var.create_usage_data_bucket ? 1 : 0
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.6.0"

  bucket           = var.usage_data_bucket_name
  attach_policy    = true
  force_destroy    = false
  object_ownership = "BucketOwnerEnforced"
  policy           = data.aws_iam_policy_document.athena_policy_usage_data.json

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = aws_kms_key.cost_analysis.arn
      }
    }
  }
}

# bucket policy to allow athena and quicksight to access the bucket
data "aws_iam_policy_document" "athena_policy_usage_data" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${module.s3_bucket_usage_data[0].s3_bucket_arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["athena.amazonaws.com"]
    }
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["${module.s3_bucket_usage_data[0].s3_bucket_arn}"]
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
      "${module.s3_bucket_usage_data[0].s3_bucket_arn}",
      "${module.s3_bucket_usage_data[0].s3_bucket_arn}/*"
    ]
    principals {
      type        = "AWS"
      identifiers = [local.quicksight_default_role]
    }
  }
}
