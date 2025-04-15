# Create the Glue catalog table for SonarQube cost data (raw format)
resource "aws_glue_catalog_table" "sonarqube_cost_data" {
  name          = "sonarqube_cost_data"
  database_name = var.athena_database_name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL         = "TRUE"
    "classification" = "ion"
    "typeOfData"     = "file"
  }

  storage_descriptor {
    location      = "s3://${var.bucket_name}/projects/"
    input_format  = "com.amazon.ionhiveserde.formats.IonInputFormat"
    output_format = "com.amazon.ionhiveserde.formats.IonOutputFormat"

    ser_de_info {
      serialization_library = "com.amazon.ionhiveserde.IonHiveSerDe"
    }

    columns {
      name = "extractedTenant"
      type = "string"
    }
    columns {
      name = "projectKey"
      type = "string"
    }
    columns {
      name = "projectName"
      type = "string"
    }
    columns {
      name = "linesOfCode"
      type = "bigint"
    }
    columns {
      name = "licenseUsagePercentage"
      type = "decimal(10,6)"
    }
    columns {
      name = "timestamp"
      type = "string"
    }
  }
}

# Quicksight dataset
resource "aws_quicksight_data_set" "cost_analysis" {
  count          = var.create_quicksight_data_set ? 1 : 0
  aws_account_id = data.aws_caller_identity.current.account_id
  data_set_id    = "${var.athena_workgroup_name}_athena"
  name           = "${var.athena_workgroup_name}_athena"
  import_mode    = "SPICE"
  physical_table_map {
    physical_table_map_id = "cost-data"
    custom_sql {
      data_source_arn = var.quicksight_data_source_arn
      name            = "sonarqube_cost_data"
      sql_query       = "SELECT * FROM ${var.athena_database_name}.sonarqube_cost_data"
      columns {
        name = "extractedTenant"
        type = "STRING"
      }
      columns {
        name = "projectKey"
        type = "STRING"
      }
      columns {
        name = "projectName"
        type = "STRING"
      }
      columns {
        name = "linesOfCode"
        type = "INTEGER"
      }
      columns {
        name = "licenseUsagePercentage"
        type = "DECIMAL"
      }
      columns {
        name = "timestamp"
        type = "DATETIME"
      }
    }
  }

  dynamic "permissions" {
    for_each = toset(var.quicksight_data_set_permissions)
    content {
      principal = permissions.value.principal
      actions   = permissions.value.actions
    }
  }
}

# Create the view as a virtual table
# resource "aws_glue_catalog_table" "sonarqube_cost_data" {
#   name          = "sonarqube_cost_data"
#   database_name = var.athena_database_name
#   table_type    = "VIRTUAL_VIEW"

#   parameters = {
#     presto_view = "true"
#     comment     = "View that converts string timestamps to proper timestamps"
#   }

#   storage_descriptor {
#     ser_de_info {
#       serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
#     }

#     columns {
#       name = "extractedTenant"
#       type = "string"
#     }
#     columns {
#       name = "projectKey"
#       type = "string"
#     }
#     columns {
#       name = "projectName"
#       type = "string"
#     }
#     columns {
#       name = "linesOfCode"
#       type = "bigint"
#     }
#     columns {
#       name = "licenseUsagePercentage"
#       type = "decimal(10,6)"
#     }
#     columns {
#       name = "timestamp"
#       type = "timestamp"
#     }
#   }

#   view_original_text = jsonencode({
#     "originalSql" = "SELECT extractedTenant, projectKey, projectName, linesOfCode, licenseUsagePercentage, CAST(from_iso8601_timestamp(timestamp) AS timestamp) as timestamp FROM ${var.athena_database_name}.sonarqube_cost_data_raw"
#     "catalog"     = "awsdatacatalog"
#     "schema"      = var.athena_database_name
#     "columns" = [
#       { "name" = "extractedTenant", "type" = "string" },
#       { "name" = "projectKey", "type" = "string" },
#       { "name" = "projectName", "type" = "string" },
#       { "name" = "linesOfCode", "type" = "bigint" },
#       { "name" = "licenseUsagePercentage", "type" = "decimal(10,6)" },
#       { "name" = "timestamp", "type" = "timestamp" }
#     ]
#   })
#   view_expanded_text = jsonencode({
#     "originalSql" = "SELECT extractedTenant, projectKey, projectName, linesOfCode, licenseUsagePercentage, CAST(from_iso8601_timestamp(timestamp) AS timestamp) as timestamp FROM ${var.athena_database_name}.sonarqube_cost_data_raw"
#     "catalog"     = "awsdatacatalog"
#     "schema"      = var.athena_database_name
#     "columns" = [
#       { "name" = "extractedTenant", "type" = "string" },
#       { "name" = "projectKey", "type" = "string" },
#       { "name" = "projectName", "type" = "string" },
#       { "name" = "linesOfCode", "type" = "bigint" },
#       { "name" = "licenseUsagePercentage", "type" = "decimal(10,6)" },
#       { "name" = "timestamp", "type" = "timestamp" }
#     ]
#   })
# }
