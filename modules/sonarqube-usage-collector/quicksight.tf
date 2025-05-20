resource "aws_quicksight_data_set" "sonarqube_cost_usage" {
  count          = var.create_quicksight_data_set ? 1 : 0
  aws_account_id = data.aws_caller_identity.current.account_id
  data_set_id    = "sonarqube_cost_usage"
  name           = "SonarQube Cost and Usage Analysis"
  import_mode    = "SPICE"

  physical_table_map {
    physical_table_map_id = "sonarqube-view"
    custom_sql {
      data_source_arn = var.quicksight_data_source_arn
      name            = "sonarqube_cost_usage"
      sql_query       = "SELECT * FROM ${var.athena_database_name}.sonarqube_cost_usage_view"

      # Define all the columns from the view
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

  # Set permissions for the dataset
  dynamic "permissions" {
    for_each = var.quicksight_data_set_permissions != null ? toset(var.quicksight_data_set_permissions) : []
    content {
      principal = permissions.value.principal
      actions   = permissions.value.actions
    }
  }
}
