# Create the Glue catalog table for SonarQube cost data (raw format)
resource "aws_glue_catalog_table" "sonarqube_cost_data_raw" {
  name          = "sonarqube_cost_data_raw"
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
