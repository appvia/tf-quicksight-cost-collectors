terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-2" # Change this to your desired region
}

# Variables for the root module
variable "quicksight_user" {
  description = "The username of the QuickSight user who will own the dashboard"
  type        = string
  default     = "default" # Change this to your QuickSight username
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Example caller for the Athena shared module
module "shared" {
  source = "./modules/shared"

  # Required variables
  results_bucket_name = "my-athena-results-bucket" # Replace with your desired bucket name

  # Optional variables with defaults
  workgroup_name   = "cost_analysis_workgroup"   # Optional: defaults to "cost_analysis_workgroup"
  database_name    = "cost_analysis"             # Optional: defaults to "cost_analysis"
  athena_role_name = "athena_cost_analysis_role" # Optional: defaults to "athena_cost_analysis_role"
  key_alias        = "cost-analysis-key"         # Optional: defaults to "cost-analysis-key"

  tags = {
    Environment = "production"
    Project     = "Cost Analysis"
    ManagedBy   = "terraform"
  }
}

# Example caller for the SonarQube usage collector module
module "sonarqube_usage_collector" {
  source = "./modules/sonarqube-usage-collector"

  # Required variables
  usage_data_bucket_name    = "my-sonarqube-usage-data" # Replace with your desired bucket name
  athena_workgroup_name     = module.shared.workgroup_name
  athena_database_name      = module.shared.database_name
  usage_data_bucket_key_arn = module.shared.kms_key_arn

  # QuickSight integration
  create_quicksight_data_set = true
  quicksight_data_source_arn = module.shared.quicksight_data_source_arn
  quicksight_data_set_permissions = [
    {
      principal = "arn:aws:quicksight:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:user/default/${var.quicksight_user}"
      actions   = ["quicksight:Describedata_set", "quicksight:Describedata_setPermissions", "quicksight:Passdata_set", "quicksight:DescribeIngestion", "quicksight:ListIngestions"]
    }
  ]

  tags = {
    Environment = "production"
    Project     = "SonarQube Usage Analysis"
    ManagedBy   = "terraform"
  }
}
