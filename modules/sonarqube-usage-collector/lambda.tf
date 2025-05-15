resource "aws_lambda_function" "cost_collector" {
  function_name = "sonarqube-cost-collector"
  handler       = "lambda.handler"
  runtime       = "python3.10"
  role          = aws_iam_role.cost_collector.arn
  environment {
    variables = {
      # SONARQUBE_DOMAIN            = var.sonarqube_domain
      # SONARQUBE_PORT              = var.sonarqube_port
      # SONARQUBE_SCHEME            = var.sonarqube_scheme
      # SONARQUBE_TOKEN_SECRET_NAME = var.sonarqube_token_secret_name
      OUTPUT_BUCKET = module.s3_bucket[0].s3_bucket_id
    }
  }
  filename         = "${path.module}/lambda/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/lambda.zip")
}

data "aws_iam_policy_document" "cost_collector" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${module.s3_bucket[0].s3_bucket_arn}/*"]
  }
  statement {
    actions   = ["s3:ListBucket"]
    resources = ["${module.s3_bucket[0].s3_bucket_arn}"]
  }
}

resource "aws_iam_policy" "cost_collector" {
  name        = "sonarqube-cost-collector"
  description = "Policy for the sonarqube cost collector"
  policy      = data.aws_iam_policy_document.cost_collector.json
}

resource "aws_iam_role_policy_attachment" "cost_collector" {
  role       = aws_iam_role.cost_collector.name
  policy_arn = aws_iam_policy.cost_collector.arn
}

resource "aws_iam_role" "cost_collector" {
  name               = "sonarqube-cost-collector"
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
