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

# Create a view that converts the string timestamp to a proper timestamp
resource "aws_athena_named_query" "sonarqube_cost_data_view" {
  name        = "create_sonarqube_cost_data_view"
  workgroup   = var.athena_workgroup_name
  database    = var.athena_database_name
  description = "Creates a view with properly formatted timestamps"
  query       = <<-EOF
    CREATE OR REPLACE VIEW sonarqube_cost_data AS
    SELECT
      extractedTenant,
      projectKey,
      projectName,
      linesOfCode,
      licenseUsagePercentage,
      from_iso8601_timestamp(timestamp) as timestamp
    FROM sonarqube_cost_data_raw;
  EOF
}
