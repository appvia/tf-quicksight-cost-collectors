# Get current AWS account ID
data "aws_caller_identity" "current" {}

data "aws_vpc" "this" {
  count = var.vpc_name != null ? 1 : 0
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}
