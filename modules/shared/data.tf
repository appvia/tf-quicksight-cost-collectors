# Get current region
data "aws_region" "current" {}

# Get current AWS account ID
data "aws_caller_identity" "current" {}
