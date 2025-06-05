# Create the Glue catalog table for Gitlab usage data (raw format)
resource "aws_glue_catalog_table" "gitlab_usage_data" {
  name          = "gitlab_usage_data"
  database_name = var.athena_database_name
  table_type    = "EXTERNAL_TABLE"
  description   = "Athena table for Gitlab license (active users) usage data, partitioned by billing_period."

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
    "storage.location.template" = "s3://${var.usage_data_bucket_name}/gitlab/$${billing_period}/"
  }

  # Defines the schema and storage properties of the table
  storage_descriptor {
    location = "s3://${var.usage_data_bucket_name}/gitlab/"

    # Definition of the data columns within your JSON files
    columns {
      name    = "tenant"
      type    = "string"
      comment = "The tenant extracted from the source."
    }
    columns {
      name    = "email"
      type    = "string"
      comment = "The email of the user"
    }
    columns {
      name    = "name"
      type    = "string"
      comment = "The name of the user."
    }
    columns {
      name    = "username"
      type    = "string"
      comment = "The username of the user."
    }
    columns {
      name    = "state"
      type    = "string"
      comment = "The state of the user (e.g., active, disabled)."
    }
    columns {
      name    = "collection_timestamp"
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

        "mapping.tenant"               = "tenant"
        "mapping.id"                   = "id"
        "mapping.name"                 = "name"
        "mapping.username"             = "username"
        "mapping.state"                = "state"
        "mapping.collection_timestamp" = "collection_timestamp"

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
