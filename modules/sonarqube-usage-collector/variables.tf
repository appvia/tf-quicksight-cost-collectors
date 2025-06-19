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

variable "sonarqube_domain" {
  description = "Domain of the SonarQube server"
  type        = string
}

variable "sonarqube_port" {
  description = "Port number of the SonarQube server"
  type        = string
  default     = "9000"
}

variable "sonarqube_scheme" {
  description = "Scheme for the SonarQube server (http or https)"
  type        = string
  default     = "https"
}

variable "sonarqube_token_secret_name" {
  description = "Name of the AWS Secrets Manager secret containing the SonarQube token"
  type        = string
}

variable "athena_table_name" {
  description = "Name of the Athena table containing project information"
  type        = string
}
