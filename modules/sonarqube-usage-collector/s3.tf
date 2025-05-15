# Bucket to put the cost data
module "s3_bucket" {
  # the import bucket goes into the account used for importing (ie prod)
  count = var.enable_bucket ? 1 : 0

  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.6.0"

  bucket = var.bucket_name

  attach_policy    = true
  force_destroy    = var.force_destroy_bucket
  object_ownership = "BucketOwnerEnforced"
  policy           = data.aws_iam_policy_document.bucket_policy.json

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = var.kms_key_arn
      }
    }
  }

  versioning = {
    enabled = true
  }

  tags = var.tags
}

# Bucket policy to allow the cost collector lambda to put the data into the bucket
data "aws_iam_policy_document" "bucket_policy" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${module.s3_bucket[0].s3_bucket_arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
  statement {
    actions   = ["s3:ListBucket"]
    resources = ["${module.s3_bucket[0].s3_bucket_arn}"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}
