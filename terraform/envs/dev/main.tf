

module "dynamodb" {
  source    = "../../modules/global-table"
  name      = "my-global-table"
  hash_key  = "pk"
  range_key = "sk"
  replica_regions = ["us-west-2", "eu-west-1"]
}