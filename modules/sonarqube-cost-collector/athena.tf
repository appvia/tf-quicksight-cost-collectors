# Create the Glue catalog table for SonarQube cost data
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
      type = "timestamp"
    }
  }
}
