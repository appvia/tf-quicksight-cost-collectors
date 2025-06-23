# s3 bucket for cost data
module "s3_bucket_cost_data" {
  count   = var.create_cost_data_bucket ? 1 : 0
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.6.0"

  bucket           = var.cost_data_bucket_name
  attach_policy    = true
  force_destroy    = false
  object_ownership = "BucketOwnerEnforced"
  policy           = data.aws_iam_policy_document.athena_policy_cost_data.json

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = aws_kms_key.cost_analysis.arn
      }
    }
  }
}

# bucket policy to allow athena and quicksight to access the bucket
data "aws_iam_policy_document" "athena_policy_cost_data" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${module.s3_bucket_cost_data[0].s3_bucket_arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["athena.amazonaws.com"]
    }
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [module.s3_bucket_cost_data[0].s3_bucket_arn]
    principals {
      type        = "Service"
      identifiers = ["athena.amazonaws.com"]
    }
  }
  # Add QuickSight permissions
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:GetBucketLocation"
    ]
    resources = [
      module.s3_bucket_cost_data[0].s3_bucket_arn,
      "${module.s3_bucket_cost_data[0].s3_bucket_arn}/*"
    ]
    principals {
      type        = "AWS"
      identifiers = [local.quicksight_default_role]
    }
  }
}

# Create the Glue catalog table for application cost data (ie how much a license costs for a set period)
resource "aws_glue_catalog_table" "application_cost_data" {
  count         = var.create_cost_data_bucket ? 1 : 0
  name          = "application_cost_data"
  database_name = aws_athena_database.cost_analysis.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL         = "TRUE"
    "classification" = "ion"
    "typeOfData"     = "file"
  }

  storage_descriptor {
    location      = "s3://${module.s3_bucket_cost_data[0].s3_bucket_id}/"
    input_format  = "com.amazon.ionhiveserde.formats.IonInputFormat"
    output_format = "com.amazon.ionhiveserde.formats.IonOutputFormat"

    ser_de_info {
      serialization_library = "com.amazon.ionhiveserde.IonHiveSerDe"
    }

    columns {
      name = "application_name"
      type = "string"
    }
    columns {
      name = "source_annual_cost"
      type = "bigint"
    }
    columns {
      name = "source_currency"
      type = "string"
    }
    columns {
      name = "gbp_annual_cost"
      type = "bigint"
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
      type = "array<struct<metric_name:string,metric_weight:decimal(3,2)>>"
    }

  }
}

# Quicksight data_set
resource "aws_quicksight_data_set" "sonarqube_usage_data" {
  count          = var.create_cost_data_bucket && var.create_quicksight_data_source ? 1 : 0
  aws_account_id = data.aws_caller_identity.current.account_id
  data_set_id    = "application_cost_data_athena"
  name           = "application_cost_data_athena"
  import_mode    = "SPICE"
  physical_table_map {
    physical_table_map_id = "cost-data"
    custom_sql {
      data_source_arn = aws_quicksight_data_source.cost_analysis[0].arn
      name            = "application_cost_data"
      sql_query       = "SELECT * FROM ${aws_athena_database.cost_analysis.name}.application_cost_data"
      columns {
        name = "application_name"
        type = "STRING"
      }
      columns {
        name = "source_annual_cost"
        type = "INTEGER"
      }
      columns {
        name = "source_currency"
        type = "STRING"
      }
      columns {
        name = "gbp_annual_cost"
        type = "INTEGER"
      }
      columns {
        name = "start_date"
        type = "STRING"
      }
      columns {
        name = "end_date"
        type = "STRING"
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
