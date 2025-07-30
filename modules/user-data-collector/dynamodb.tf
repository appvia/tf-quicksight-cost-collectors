# dynamodb to store data from lambda

resource "aws_dynamodb_table" "user_data" {
  name         = "user_data"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "email"
    type = "S"
  }

  attribute {
    name = "tenant"
    type = "S"
  }

  hash_key = "email"

  global_secondary_index {
    name            = "tenant-index"
    hash_key        = "tenant"
    projection_type = "ALL"
  }
}
