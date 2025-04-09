resource "aws_lambda_function" "cost_collector" {
  function_name = "sonarqube-cost-collector"
  handler       = "lambda.handler"
  runtime       = "python3.10"
  role          = aws_iam_role.cost_collector.arn
}

data "aws_iam_policy_document" "cost_collector" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${module.s3_bucket.s3_bucket_arn}/*"]
  }
  statement {
    actions   = ["s3:ListBucket"]
    resources = ["${module.s3_bucket.s3_bucket_arn}"]
  }
}

resource "aws_iam_role_policy_attachment" "cost_collector" {
  role       = aws_iam_role.cost_collector.name
  policy_arn = data.aws_iam_policy_document.cost_collector.arn
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
