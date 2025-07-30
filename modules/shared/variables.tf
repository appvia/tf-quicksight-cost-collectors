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

variable "cost_data_bucket_name" {
  description = "Name of the S3 bucket for cost data"
  type        = string
  default     = "cost-data-bucket"
}

variable "create_cost_data_bucket" {
  description = "Whether to create the cost data S3 bucket"
  type        = bool
  default     = true
}

variable "usage_data_bucket_name" {
  description = "Name of the S3 bucket for usage data"
  type        = string
  default     = "usage-data-bucket"
}

variable "create_usage_data_bucket" {
  description = "Whether to create the usage data S3 bucket"
  type        = bool
  default     = true
}

variable "athena_role_name" {
  description = "Name of the IAM role for Athena"
  type        = string
  default     = "athena_cost_analysis_role"
}

variable "key_alias" {
  description = "Alias for the KMS key"
  type        = string
  default     = "cost-analysis-key"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "create_quicksight_data_source" {
  description = "Whether to create a Quicksight data source"
  type        = bool
  default     = true
}

variable "quicksight_data_source_owners" {
  description = "Owner of the Quicksight data source"
  type        = list(string)
  default     = []
}

variable "enabled_collectors" {
  description = "List of enabled collectors"
  type = list(object({
    name        = string
    lambda_role = string
    s3_prefix   = string
  }))
}

variable "quicksight_data_set_permissions" {
  description = "Permissions for the Quicksight data set"
  type = list(object({
    principal = string
    actions   = list(string)
  }))
  default = []
}

variable "vpc_name" {
  description = "Name tag of the VPC to use for Lambda functions"
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "ID of the VPC to use for Lambda functions"
  type        = string
  default     = null
}

variable "subnet_names" {
  description = "Name tags of the subnets to use for Lambda functions"
  type        = list(string)
  default     = []
}

variable "subnet_ids" {
  description = "IDs of the subnets to use for Lambda functions"
  type        = list(string)
  default     = []
}

variable "security_group_names" {
  description = "Name tags of the security groups to use for Lambda functions"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "IDs of the security groups to use for Lambda functions"
  type        = list(string)
  default     = []
}
