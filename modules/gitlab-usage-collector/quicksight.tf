# resource "aws_quicksight_data_set" "gitlab_cost_usage" {
#   count          = var.create_quicksight_data_set ? 1 : 0
#   aws_account_id = data.aws_caller_identity.current.account_id
#   data_set_id    = "gitlab_cost_usage"
#   name           = "gitlab Cost and Usage Analysis"
#   import_mode    = "SPICE"

#   physical_table_map {
#     physical_table_map_id = "gitlab-view"
#     custom_sql {
#       data_source_arn = var.quicksight_data_source_arn
#       name            = "gitlab_cost_usage"
#       sql_query       = "SELECT * FROM ${var.athena_database_name}.gitlab_daily_cost_usage_view"

#       # Define all the columns from the view
#       columns {
#         name = "tenant"
#         type = "STRING"
#       }
#       columns {
#         name = "id"
#         type = "STRING"
#       }
#       columns {
#         name = "gitlab_project_name"
#         type = "STRING"
#       }
#       columns {
#         name = "gitlab_lines_of_code"
#         type = "INTEGER"
#       }
#       columns {
#         name = "gitlab_license_usage_percentage"
#         type = "DECIMAL"
#       }
#       columns {
#         name = "gitlab_collection_timestamp"
#         type = "DATETIME"
#       }
#       columns {
#         name = "collection_date"
#         type = "STRING"
#       }
#       columns {
#         name = "billing_period"
#         type = "STRING"
#       }
#       columns {
#         name = "application_name"
#         type = "STRING"
#       }
#       columns {
#         name = "gbp_annual_cost"
#         type = "INTEGER"
#       }
#       columns {
#         name = "daily_cost"
#         type = "DECIMAL"
#       }
#       columns {
#         name = "project_daily_cost"
#         type = "DECIMAL"
#       }
#     }
#   }

#   # Set permissions for the dataset
#   dynamic "permissions" {
#     for_each = var.quicksight_data_set_permissions != null ? toset(var.quicksight_data_set_permissions) : []
#     content {
#       principal = permissions.value.principal
#       actions   = permissions.value.actions
#     }
#   }
# }

# resource "aws_quicksight_data_set" "gitlab_billing_period_usage" {
#   count          = var.create_quicksight_data_set ? 1 : 0
#   aws_account_id = data.aws_caller_identity.current.account_id
#   data_set_id    = "gitlab_billing_period_usage"
#   name           = "gitlab Billing Period Usage Analysis"
#   import_mode    = "SPICE"

#   physical_table_map {
#     physical_table_map_id = "gitlab-billing-period-view"
#     custom_sql {
#       data_source_arn = var.quicksight_data_source_arn
#       name            = "gitlab_billing_period_usage"
#       sql_query       = "SELECT * FROM ${var.athena_database_name}.gitlab_billing_period_cost_view"

#       columns {
#         name = "billing_period"
#         type = "STRING"
#       }
#       columns {
#         name = "tenant"
#         type = "STRING"
#       }
#       columns {
#         name = "gitlab_project_key"
#         type = "STRING"
#       }
#       columns {
#         name = "gitlab_project_name"
#         type = "STRING"
#       }
#       columns {
#         name = "avg_daily_project_cost"
#         type = "DECIMAL"
#       }
#       columns {
#         name = "days_in_billing_period"
#         type = "INTEGER"
#       }
#       columns {
#         name = "data_points_in_month"
#         type = "INTEGER"
#       }
#       columns {
#         name = "extrapolated_monthly_project_cost"
#         type = "DECIMAL"
#       }
#     }
#   }

#   # Set permissions for the dataset
#   dynamic "permissions" {
#     for_each = var.quicksight_data_set_permissions != null ? toset(var.quicksight_data_set_permissions) : []
#     content {
#       principal = permissions.value.principal
#       actions   = permissions.value.actions
#     }
#   }
# }
