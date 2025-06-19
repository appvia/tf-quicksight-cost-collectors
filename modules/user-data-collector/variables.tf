variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
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

variable "gitlab_ignore_ssl" {
  description = "Ignore SSL certificate verification for GitLab server (useful for self-signed certificates)"
  type        = bool
  default     = false
}

variable "gitlab_base_url" {
  description = "Base URL of the GitLab server"
  type        = string
  default     = "https://gitlab.example.com"
}

variable "gitlab_project_id" {
  description = "GitLab project ID containing the user data file"
  type        = string
  default     = "13083"
}

variable "gitlab_access_token_secret_name" {
  description = "Name of the AWS Secrets Manager secret containing the GitLab access token"
  type        = string
  default     = "gitlab-access-token"
}

variable "gitlab_file_path" {
  description = "Path to the user data file in the GitLab repository"
  type        = string
  default     = "users.json"
}

variable "gitlab_ref" {
  description = "Git reference (branch/tag) to fetch the file from"
  type        = string
  default     = "main"
}
