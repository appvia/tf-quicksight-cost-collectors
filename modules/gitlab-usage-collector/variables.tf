variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "usage_data_bucket_name" {
  description = "Name of the S3 bucket where usage data is stored"
  type        = string
}

variable "athena_workgroup_name" {
  description = "Name of the Athena workgroup from the shared module"
  type        = string
}

variable "athena_database_name" {
  description = "Name of the Athena database from the shared module"
  type        = string
}

variable "create_quicksight_data_set" {
  description = "Whether to create a Quicksight data set"
  type        = bool
  default     = true
}

variable "quicksight_data_source_arn" {
  description = "ARN of the Quicksight data source"
  type        = string
}

variable "quicksight_data_set_permissions" {
  description = "Permissions for the Quicksight data set"
  type = list(object({
    principal = string
    actions   = list(string)
  }))
  default = []
}


variable "usage_data_bucket_key_arn" {
  description = "ARN of the KMS key for the usage data bucket"
  type        = string
}

variable "mock_mode" {
  description = "Enable mock mode for testing the lambda function"
  type        = bool
  default     = false
}

variable "vpc_config" {
  description = "VPC configuration for the Lambda function"
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "lambda_zip_output_path" {
  description = "Output path for the lambda zip file"
  type        = string
  default     = "build/lambda.zip"
}

variable "log_retention_in_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 14
}

variable "gitlab_domain" {
  description = "Domain of the GitLab server"
  type        = string
  default     = "localhost"
}

variable "gitlab_port" {
  description = "Port number of the GitLab server"
  type        = string
  default     = "443"
}

variable "gitlab_scheme" {
  description = "Scheme for the GitLab server (http or https)"
  type        = string
  default     = "https"
}

variable "gitlab_token_secret_name" {
  description = "Name of the AWS Secrets Manager secret containing the GitLab token"
  type        = string
  default     = "gitlab-token"
}

variable "gitlab_ignore_ssl" {
  description = "Ignore SSL certificate verification for GitLab server (useful for self-signed certificates)"
  type        = bool
  default     = false
}

variable "gitlab_required_fields" {
  description = "Required fields for GitLab users ('all' or comma-separated list)"
  type        = string
  default     = "all"
}

variable "gitlab_external_users" {
  description = "Include external users in GitLab data collection"
  type        = bool
  default     = false
}

variable "gitlab_active_users_only" {
  description = "Only collect active users from GitLab"
  type        = bool
  default     = false
}

variable "user_data_dynamodb_table_name" {
  description = "Name of the DynamoDB table for user-tenant mapping"
  type        = string
  default     = "user-data-tenant-table"
}
