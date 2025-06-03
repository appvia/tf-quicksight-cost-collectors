resource "aws_lambda_function" "collector" {
  function_name = "user-data-collector"
  handler       = "lambda.handler"
  runtime       = "python3.12"
  role          = aws_iam_role.collector.arn

  timeout = 120
  environment {
    variables = {
      MOCK_MODE = var.mock_mode
    }
  }
  filename         = "${path.module}/lambda/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/lambda.zip")
}

data "aws_iam_policy_document" "collector" {
  statement {
    actions   = ["dynamodb:PutItem", "dynamodb:GetItem"]
    resources = [aws_dynamodb_table.user_data.arn]
  }
}

resource "aws_iam_policy" "collector" {
  name        = "user-data-collector"
  description = "Policy for the user data collector"
  policy      = data.aws_iam_policy_document.collector.json
}

resource "aws_iam_role_policy_attachment" "collector" {
  role       = aws_iam_role.collector.name
  policy_arn = aws_iam_policy.collector.arn
}

resource "aws_iam_role" "collector" {
  name               = "user-data-collector"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}
