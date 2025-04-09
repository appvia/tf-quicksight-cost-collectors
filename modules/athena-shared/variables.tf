variable "workgroup_name" {
  description = "Name of the Athena workgroup"
  type        = string
  default     = "cost_analysis_workgroup"
}

variable "database_name" {
  description = "Name of the Athena database"
  type        = string
  default     = "cost_analysis"
}

variable "results_bucket_name" {
  description = "Name of the S3 bucket for Athena query results"
  type        = string
}

variable "athena_role_name" {
  description = "Name of the IAM role for Athena"
  type        = string
  default     = "athena_cost_analysis_role"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
