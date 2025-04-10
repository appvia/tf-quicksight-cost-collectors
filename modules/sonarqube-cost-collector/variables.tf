variable "enable_bucket" {
  type    = bool
  default = true
}

variable "bucket_name" {
  type    = string
  default = "sonarqube-cost-collector"
}

variable "force_destroy_bucket" {
  type    = bool
  default = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "athena_workgroup_name" {
  description = "Name of the Athena workgroup from the shared module"
  type        = string
}

variable "athena_database_name" {
  description = "Name of the Athena database from the shared module"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key to use for encryption"
  type        = string
}
