# The sql_files variable has been removed in favor of using sql_directory_path

variable "bucket_name" {
  description = "Name of the S3 bucket to create for storing SQL files. If not provided, a random name will be generated."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "athena_workgroup" {
  description = "Name of the Athena workgroup to use for queries"
  type        = string
  default     = "primary"
}

variable "athena_database" {
  description = "Name of the Athena database where views will be created"
  type        = string
}

variable "athena_results_bucket_name" {
  description = "Name of the S3 bucket where Athena query results will be stored. The Lambda role will be granted permissions to write to this bucket."
  type        = string
}

variable "lambda_timeout" {
  description = "Timeout for the Lambda function in seconds"
  type        = number
  default     = 300
}

variable "lambda_memory_size" {
  description = "Memory size for the Lambda function in MB"
  type        = number
  default     = 256
}

variable "create_lambda_log_group" {
  description = "Whether to create a CloudWatch log group for Lambda logs"
  type        = bool
  default     = true
}

variable "lambda_log_retention_days" {
  description = "Number of days to retain Lambda logs"
  type        = number
  default     = 14
}

variable "enable_notification" {
  description = "Enable S3 event notifications to trigger Lambda"
  type        = bool
  default     = true
}

variable "sql_directory_path" {
  description = "Path to the directory containing SQL files to be uploaded to S3. All SQL files (*.sql) in this directory, including those in subdirectories, will be uploaded to the bucket with their relative paths preserved."
  type        = string
  default     = "./sql"
}
