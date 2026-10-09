
output "dynamodb_arn" {
  value = aws_dynamodb_table.this.arn
}

output "dynamodb_name" {
  value = aws_dynamodb_table.this.name
}