# Create a local variable for the Presto view SQL query
locals {
  view_sql = <<-EOT
    WITH usage_data AS (
      SELECT
        sonarqube_extracted_tenant,
        sonarqube_project_key,
        sonarqube_project_name,
        sonarqube_lines_of_code,
        sonarqube_license_usage_percentage,
        sonarqube_collection_timestamp,
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
      c.daily_cost * (u.sonarqube_license_usage_percentage / 100.0) as project_daily_cost
    FROM
      usage_data u
    JOIN
      cost_data c
    ON
      u.collection_date BETWEEN c.start_date AND c.end_date
  EOT

  # Format according to the Presto view definition format
  presto_view = jsonencode({
    "catalog"     = "awsdatacatalog"
    "schema"      = var.athena_database_name
    "originalSql" = local.view_sql
  })
}

# Create an Athena view as a Glue catalog table
resource "aws_glue_catalog_table" "sonarqube_cost_usage_view" {
  name          = "sonarqube_cost_usage_view"
  database_name = var.athena_database_name
  table_type    = "VIRTUAL_VIEW"
  description   = "View that joins SonarQube usage data with application cost data to calculate costs per project"

  parameters = {
    presto_view = "true"
    comment     = "Athena view joining sonarqube usage data with cost data"
  }

  # Define the view using the Presto format - this is the required format for Athena views in Glue
  view_original_text = "/* Presto View: ${base64encode(local.presto_view)} */"

  # Define the columns in the view
  storage_descriptor {
    # Required for Athena views
    ser_de_info {
      name                  = "-"
      serialization_library = "-"
    }

    # Set location to empty for views
    location = ""

    columns {
      name = "sonarqube_extracted_tenant"
      type = "string"
    }
    columns {
      name = "sonarqube_project_key"
      type = "string"
    }
    columns {
      name = "sonarqube_project_name"
      type = "string"
    }
    columns {
      name = "sonarqube_lines_of_code"
      type = "int"
    }
    columns {
      name = "sonarqube_license_usage_percentage"
      type = "double"
    }
    columns {
      name = "sonarqube_collection_timestamp"
      type = "timestamp"
    }
    columns {
      name = "collection_date"
      type = "string"
    }
    columns {
      name = "billing_period"
      type = "string"
    }
    columns {
      name = "application_name"
      type = "string"
    }
    columns {
      name = "gbp_annual_cost"
      type = "int"
    }
    columns {
      name = "daily_cost"
      type = "double"
    }
    columns {
      name = "project_daily_cost"
      type = "double"
    }
  }
}

# Create a simpler QuickSight dataset that just queries the view
resource "aws_quicksight_data_set" "sonarqube_cost_usage" {
  count          = var.create_quicksight_data_set ? 1 : 0
  aws_account_id = data.aws_caller_identity.current.account_id
  data_set_id    = "sonarqube_cost_usage"
  name           = "SonarQube Cost and Usage Analysis"
  import_mode    = "SPICE"

  # Single physical table using a simple SQL query on the view
  physical_table_map {
    physical_table_map_id = "sonarqube-view"
    custom_sql {
      data_source_arn = var.quicksight_data_source_arn
      name            = "sonarqube_cost_usage"
      sql_query       = "SELECT * FROM ${var.athena_database_name}.${aws_glue_catalog_table.sonarqube_cost_usage_view.name}"

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

# Output the dataset ARN for use in dashboards or other resources
output "quicksight_dataset_arn" {
  description = "ARN of the SonarQube cost and usage QuickSight dataset"
  value       = var.create_quicksight_data_set ? aws_quicksight_data_set.sonarqube_cost_usage[0].arn : null
}
