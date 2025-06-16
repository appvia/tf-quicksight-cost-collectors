output "workgroup_name" {
  description = "Name of the Athena workgroup"
  value       = aws_athena_workgroup.cost_analysis.name
}

output "database_name" {
  description = "Name of the Athena database"
  value       = aws_athena_database.cost_analysis.name
}

output "athena_role_arn" {
  description = "ARN of the Athena IAM role"
  value       = aws_iam_role.athena_role.arn
}

output "athena_role_name" {
  description = "Name of the Athena IAM role"
  value       = aws_iam_role.athena_role.name
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for encryption"
  value       = aws_kms_key.cost_analysis.arn
}

output "quicksight_data_source_arn" {
  description = "ARN of the Quicksight data source"
  value       = var.create_quicksight_data_source ? aws_quicksight_data_source.cost_analysis[0].arn : null
}

output "usage_data_bucket_name" {
  description = "Name of the S3 bucket for usage data"
  value       = var.create_usage_data_bucket ? module.s3_bucket_usage_data[0].s3_bucket_id : null
}

output "results_bucket_name" {
  description = "Name of the S3 bucket for Athena query results"
  value       = module.s3_bucket_results.s3_bucket_id
}

output "lambda_vpc_config" {
  description = "VPC configuration for Lambda functions"
  value = length(data.aws_subnets.lambda_subnets) > 0 && length(data.aws_security_groups.lambda_security_groups) > 0 ? {
    subnet_ids         = data.aws_subnets.lambda_subnets[0].ids
    security_group_ids = data.aws_security_groups.lambda_security_groups[0].ids
  } : null
}
