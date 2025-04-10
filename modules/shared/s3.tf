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

# bucket policy to allow athena to write to the bucket
data "aws_iam_policy_document" "athena_policy" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${module.s3_bucket.s3_bucket_arn}/*"]
  }
}
