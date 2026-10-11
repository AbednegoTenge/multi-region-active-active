data "archive_file" "lambda" {
    type = "zip"
    source_dir = "${path.module}/lambda"
    output_path = "${path.module}/lambda.zip"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.region}-lambda-execution-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role      = aws_iam_role.lambda.name
}


resource "aws_iam_role_policy" "lambda" {
  name   = "${local.region}-lambda_execution_policy"
  role   = aws_iam_role.lambda.id
  policy = jsonencode({
   "Version": "2012-10-17",
   "Statement": [
     {
       "Action": [
         "dynamodb:PutItem",
         "dynamodb:GetItem",
       ],
       "Effect": "Allow",
       "Resource": "arn:aws:dynamodb:${local.region}:*:table/${var.table_name}"
    }
   ]
  })
}

resource "aws_lambda_function" "this" {
  function_name = "${local.region}-lambda-function"
  role          = aws_iam_role.lambda.arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  timeout       = 5
  filename      = data.archive_file.lambda.output_path

  source_code_hash = data.archive_file.lambda.output_base64sha256
  environment {
    variables = { TABLE_NAME = var.table_name }
  }
}

resource "aws_lambda_permission" "allow_lb" {
  function_name = aws_lambda_function.this.function_name
  action        = "lambda:InvokeFunction"
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.this.arn
}