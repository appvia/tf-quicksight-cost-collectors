# Create a joined data set that combines application costs with usage data
resource "aws_quicksight_data_set" "sonarqube_cost_usage_joined" {
  count          = var.create_quicksight_data_set ? 1 : 0
  aws_account_id = data.aws_caller_identity.current.account_id
  data_set_id    = "sonarqube_cost_usage_joined"
  name           = "SonarQube Cost and Usage Joined"
  import_mode    = "SPICE"

  # Single physical table using a join in custom SQL
  physical_table_map {
    physical_table_map_id = "joined-data"
    custom_sql {
      data_source_arn = var.quicksight_data_source_arn
      name            = "sonarqube_cost_usage_joined"
      sql_query       = <<-EOT
        WITH usage_data AS (
          SELECT
            sonarqube_extracted_tenant,
            sonarqube_project_key,
            sonarqube_project_name,
            sonarqube_lines_of_code,
            sonarqube_license_usage_percentage,
            sonarqube_collection_timestamp,
            -- Use date_format function (lowercase in Athena)
            date_format(sonarqube_collection_timestamp, '%Y-%m-%d') as collection_date,
            billing_period
          FROM
            ${var.athena_database_name}.sonarqube_usage_data
        ),
        
        cost_data AS (
          SELECT 
            application_name,
            gbp_annual_cost,
            ROUND(gbp_annual_cost / 365.0, 2) AS daily_cost,
            start_date,
            end_date
          FROM 
            ${var.athena_database_name}.application_cost_data
          WHERE 
            application_name = 'sonarqube'
        )
        
        SELECT
          u.sonarqube_extracted_tenant,
          u.sonarqube_project_key,
          u.sonarqube_project_name,
          u.sonarqube_lines_of_code,
          u.sonarqube_license_usage_percentage,
          u.sonarqube_collection_timestamp,
          u.collection_date,
          u.billing_period,
          c.application_name,
          c.gbp_annual_cost,
          c.daily_cost,
          -- Calculate the cost per project based on license usage percentage
          -- Direct calculation: daily cost * (license usage percentage / 100)
          c.daily_cost * (u.sonarqube_license_usage_percentage / 100.0) as project_daily_cost
        FROM
          usage_data u
        JOIN
          cost_data c
        ON
          -- Join on date - the collection date must be within the cost data date range
          u.collection_date BETWEEN c.start_date AND c.end_date
      EOT
      columns {
        name = "sonarqube_extracted_tenant"
        type = "STRING"
      }
      columns {
        name = "sonarqube_project_key"
        type = "STRING"
      }
      columns {
        name = "sonarqube_project_name"
        type = "STRING"
      }
      columns {
        name = "sonarqube_lines_of_code"
        type = "INTEGER"
      }
      columns {
        name = "sonarqube_license_usage_percentage"
        type = "DECIMAL"
      }
      columns {
        name = "sonarqube_collection_timestamp"
        type = "DATETIME"
      }
      columns {
        name = "collection_date"
        type = "STRING"
      }
      columns {
        name = "billing_period"
        type = "STRING"
      }
      columns {
        name = "application_name"
        type = "STRING"
      }
      columns {
        name = "gbp_annual_cost"
        type = "INTEGER"
      }
      columns {
        name = "daily_cost"
        type = "DECIMAL"
      }
      columns {
        name = "project_daily_cost"
        type = "DECIMAL"
      }
    }
  }

  # Set permissions for the joined data_set
  dynamic "permissions" {
    for_each = var.quicksight_data_set_permissions != null ? toset(var.quicksight_data_set_permissions) : []
    content {
      principal = permissions.value.principal
      actions   = permissions.value.actions
    }
  }
}

# Output the data_set ARN for use in dashboards or other resources
output "quicksight_data_set_arn" {
  description = "ARN of the SonarQube cost and usage QuickSight data_set"
  value       = var.create_quicksight_data_set ? aws_quicksight_data_set.sonarqube_cost_usage_joined[0].arn : null
}
