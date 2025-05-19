# Create the Glue catalog table for SonarQube cost data (raw format)
resource "aws_glue_catalog_table" "sonarqube_usage_data" {
  name          = "sonarqube_usage_data"
  database_name = var.athena_database_name
  table_type    = "EXTERNAL_TABLE"
  description   = "Athena table for SonarQube usage data, partitioned by billing_period."

  # Parameters for the table, including partition projection configuration
  parameters = {
    "EXTERNAL"           = "TRUE"
    "classification"     = "json"
    "projection.enabled" = "true" # Enable partition projection

    "projection.billing_period.type"          = "date"
    "projection.billing_period.format"        = "yyyy-MM"
    "projection.billing_period.range"         = "2025-01,NOW"
    "projection.billing_period.interval"      = "1"
    "projection.billing_period.interval.unit" = "MONTHS"

    # Template for the S3 location of the partitioned data.
    "storage.location.template" = "s3://${var.usage_data_bucket_name}/sonarqube/$${billing_period}/"
  }

  # Defines the schema and storage properties of the table
  storage_descriptor {
    location = "s3://${var.usage_data_bucket_name}/sonarqube/"

    # Definition of the data columns within your JSON files
    columns {
      name    = "sonarqube_extracted_tenant"
      type    = "string"
      comment = "The tenant extracted from the source."
    }
    columns {
      name    = "sonarqube_project_name"
      type    = "string"
      comment = "The display name of the project."
    }
    columns {
      name    = "sonarqube_project_key"
      type    = "string"
      comment = "The unique key for the project (data field)."
    }
    columns {
      name    = "sonarqube_lines_of_code"
      type    = "bigint"
      comment = "Number of lines of code in the project."
    }
    columns {
      name    = "sonarqube_license_usage_percentage"
      type    = "double"
      comment = "Percentage of license usage."
    }
    columns {
      name    = "sonarqube_collection_timestamp"
      type    = "timestamp" # ISO 8601 timestamps like "2025-05-16T16:05:34.228361"
      comment = "Timestamp of the data extraction."
    }

    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"


    ser_de_info {
      name                  = "JsonSerDe"
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"

      parameters = {
        "serialization.format" = "1"

        "mapping.sonarqube_extracted_tenant"         = "extracted_tenant"
        "mapping.sonarqube_project_key"              = "project_key"
        "mapping.sonarqube_project_name"             = "project_name"
        "mapping.sonarqube_lines_of_code"            = "lines_of_code"
        "mapping.sonarqube_license_usage_percentage" = "license_usage_percentage"
        "mapping.sonarqube_collection_timestamp"     = "timestamp"

        # Optional: To ignore malformed JSON records instead of failing the query
        # "ignore.malformed.json" = "true"
      }
    }
  }

  partition_keys {
    name    = "billing_period"
    type    = "string"
    comment = "Partition key for the billing period, e.g., 2025-05"
  }
}

# Quicksight dataset
resource "aws_quicksight_data_set" "sonarqube_usage_data" {
  count          = var.create_quicksight_data_set ? 1 : 0
  aws_account_id = data.aws_caller_identity.current.account_id
  data_set_id    = "${var.athena_workgroup_name}_athena"
  name           = "${var.athena_workgroup_name}_athena"
  import_mode    = "SPICE"
  physical_table_map {
    physical_table_map_id = "cost-data"
    custom_sql {
      data_source_arn = var.quicksight_data_source_arn
      name            = "sonarqube_usage_data"
      sql_query       = "SELECT * FROM ${var.athena_database_name}.sonarqube_usage_data"
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
