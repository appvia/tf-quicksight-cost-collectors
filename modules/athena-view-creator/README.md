# Athena View Creator

This Terraform module provides a solution for managing Athena views using SQL files. It creates an infrastructure where:

1. SQL files are stored in an S3 bucket
2. When files are added, updated, or deleted, a Lambda function is triggered
3. The Lambda function executes the SQL in Athena to create, update, or drop views

This allows for version-controlled, CI/CD-friendly management of Athena views.

## Architecture

![Architecture Diagram](https://raw.githubusercontent.com/yourusername/tf-quicksight-cost-collectors/main/modules/athena-view-creator/architecture.png)

## Features

- **Automated view management**: Views are automatically created/updated when SQL files change
- **Version control**: SQL files can be managed in git repositories
- **Cleanup**: Views are dropped when SQL files are deleted
- **Simple interface**: Just provide SQL files and the module handles the rest
- **Flexible organization**: SQL files can be placed anywhere in the bucket, not just in a specific directory
  - For files in subdirectories, the view name is derived from the path (slashes replaced by underscores)
  - e.g., `projects/analytics/sales_view.sql` becomes view name `projects_analytics_sales_view`

## Usage

```hcl
module "athena_views" {
  source = "./modules/athena-view-creator"

  athena_database   = "my_database"
  athena_workgroup  = "primary"

  # By default, SQL files from the module's sql/ directory will be used
  # You can specify a different directory like this:
  sql_directory_path = "${path.module}/views"

  tags = {
    Environment = "Production"
    Project     = "Data Analytics"
  }
}
```

Just place your SQL files in the specified directory, and they'll be automatically uploaded to the S3 bucket. For example, with the following directory structure:

```
views/
  ├── customer_summary.sql
  ├── product_analytics.sql
  └── marketing/
      └── campaign_performance.sql
```

All three SQL files will be uploaded to the bucket, with their relative paths preserved. The resulting views will be:

- `customer_summary`
- `product_analytics`
- `marketing_campaign_performance` (path separator replaced with underscore)

```

## Requirements

| Name      | Version   |
| --------- | --------- |
| terraform | >= 0.13.0 |
| aws       | >= 3.0.0  |

## Inputs

| Name               | Description                                             | Type          | Default     | Required |
| ------------------ | ------------------------------------------------------- | ------------- | ----------- | :------: |
| athena_database    | Name of the Athena database where views will be created | `string`      | n/a         |   yes    |
| athena_results_bucket_name | Name of the S3 bucket where Athena query results will be stored | `string` | n/a | yes |
| bucket_name        | Name of the S3 bucket to create                         | `string`      | `""`        |    no    |
| athena_workgroup   | Name of the Athena workgroup                            | `string`      | `"primary"` |    no    |
| lambda_timeout     | Timeout for the Lambda function in seconds              | `number`      | `300`       |    no    |
| lambda_memory_size | Memory size for the Lambda function in MB               | `number`      | `256`       |    no    |
| sql_directory_path | Path to the directory containing SQL files to upload to S3 | `string`    | `"${path.module}/sql"` | no |
| tags               | Tags to apply to all resources                          | `map(string)` | `{}`        |    no    |

## Outputs

| Name                 | Description                 |
| -------------------- | --------------------------- |
| bucket_id            | ID of the S3 bucket         |
| bucket_arn           | ARN of the S3 bucket        |
| lambda_function_arn  | ARN of the Lambda function  |
| lambda_function_name | Name of the Lambda function |
| lambda_role_arn      | ARN of the Lambda IAM role  |
| lambda_role_name     | Name of the Lambda IAM role |

## License

This module is licensed under the MIT License.
```
