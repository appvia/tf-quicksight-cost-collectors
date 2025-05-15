output "lambda_role" {
  description = "IAM role for the collector lambda"
  value       = aws_iam_role.cost_collector
}
