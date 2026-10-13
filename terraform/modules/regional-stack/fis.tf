# Lets AWS FIS inject faults into this region's Lambda.
# FIS writes a fault config to S3; the FIS extension layer reads it on each invocation.

locals {
  fis_config_location = "${var.fis_bucket_arn}/FisConfigs/"
}

# Latest FIS extension layer ARN for this region, published by AWS in SSM.
data "aws_ssm_parameter" "fis_layer" {
  name = "/aws/service/fis/lambda-extension/AWS-FIS-extension-x86_64/1.x.x"
}

resource "aws_iam_role_policy" "fis_read" {
  name = "${local.region}-lambda-fis-read"
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = ["s3:ListBucket"]
        Resource  = var.fis_bucket_arn
        Condition = { StringLike = { "s3:prefix" = ["FisConfigs/*"] } }
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${var.fis_bucket_arn}/FisConfigs/*"
      }
    ]
  })
}
