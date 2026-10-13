variable "vpc_cidr" {
  description = "CIDR block for this region's VPC, e.g. 10.10.0.0/16. Must not overlap other regions."
  type        = string
}

variable "table_name" {
  description = "The name of the DynamoDB table to be used by the Lambda function."
  type        = string
}

variable "fis_bucket_arn" {
  description = "ARN of the S3 bucket where AWS FIS writes fault configurations for the Lambda extension to read."
  type        = string
}
