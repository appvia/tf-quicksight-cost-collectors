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
