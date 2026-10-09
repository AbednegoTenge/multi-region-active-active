

resource "aws_dynamodb_table" "this" {
  name         = var.name
  hash_key     = var.hash_key
  range_key    = var.range_key
  billing_mode = "PAY_PER_REQUEST"
  stream_enabled = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
  point_in_time_recovery {
    enabled = true
  }
  attribute {
    name = var.hash_key
    type = "S"
  }
  attribute {
    name = var.range_key
    type = "S"
  }

  dynamic "replica" {
    for_each = var.replica_regions
    content {
      region_name = replica.value
      point_in_time_recovery = true
    }
  }

  tags = var.tags
}