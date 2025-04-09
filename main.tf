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

# Example caller for the Athena shared module
module "athena_shared" {
  source = "./modules/athena-shared"

  # Required variables
  results_bucket_name = "my-athena-results-bucket" # Replace with your desired bucket name

  # Optional variables with defaults
  workgroup_name   = "cost_analysis_workgroup"   # Optional: defaults to "cost_analysis_workgroup"
  database_name    = "cost_analysis"             # Optional: defaults to "cost_analysis"
  athena_role_name = "athena_cost_analysis_role" # Optional: defaults to "athena_cost_analysis_role"

  tags = {
    Environment = "production"
    Project     = "Cost Analysis"
    ManagedBy   = "terraform"
  }
}

# Example caller for the SonarQube cost collector module
module "sonarqube_cost_collector" {
  source = "./modules/sonarqube-cost-collector"

  # Required variables - using outputs from athena_shared module
  athena_workgroup_name = module.athena_shared.workgroup_name
  athena_database_name  = module.athena_shared.database_name

  # Optional variables with defaults
  bucket_name          = "my-sonarqube-cost-collector" # Optional: defaults to "sonarqube-cost-collector"
  enable_bucket        = true                          # Optional: defaults to true
  force_destroy_bucket = true                          # Optional: defaults to true

  tags = {
    Environment = "production"
    Project     = "SonarQube Cost Analysis"
    ManagedBy   = "terraform"
  }
}
