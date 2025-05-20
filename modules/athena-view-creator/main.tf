/**
 * # Athena View Creator Module
 *
 * This module creates an automated system to manage Athena views through SQL files.
 * SQL files uploaded to an S3 bucket will automatically be executed to create or update views in Athena.
 */

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  bucket_name = var.bucket_name != "" ? var.bucket_name : "athena-views-${random_string.suffix.result}"
}

# Get the current AWS account ID for use in policies
data "aws_caller_identity" "current" {}

# Get the current AWS region for use in ARNs
data "aws_region" "current" {}
