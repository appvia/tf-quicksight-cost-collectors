# Create the Glue catalog table for application metrics data (nested structure)
resource "aws_glue_catalog_table" "application_metrics_data" {
  count         = var.create_cost_data_bucket ? 1 : 0
  name          = "application_metrics_data"
  database_name = aws_athena_database.cost_analysis.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL         = "TRUE"
    "classification" = "json"
    "typeOfData"     = "file"
  }

  storage_descriptor {
    location      = "s3://${module.s3_bucket_cost_data[0].s3_bucket_id}/metrics/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "JsonSerDe"
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"

      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "application_name"
      type = "string"
    }
    columns {
      name = "start_date"
      type = "string"
    }
    columns {
      name = "end_date"
      type = "string"
    }
    columns {
      name = "metrics"
      type = "array<struct<metric_name:string,metric_weight:int>>"
    }
  }
}
