

module "dynamodb" {
  source    = "../../modules/global-table"
  providers = { aws = aws.use1 }
  name      = "my-global-table"
  hash_key  = "pk"
  range_key = "sk"
  replica_regions = ["us-west-2", "eu-west-1"]
}

module "region_use1" {
  source = "../../modules/regional-stack"
  providers = { aws = aws.use1 }
  vpc_cidr = "10.10.0.0/16"
  table_name = module.dynamodb.dynamodb_name
}

module "region_usw2" {
  source = "../../modules/regional-stack"
  providers = { aws = aws.usw2 }
  vpc_cidr = "10.20.0.0/16"
  table_name = module.dynamodb.dynamodb_name
}

module "region_euw1" {
  source = "../../modules/regional-stack"
  providers = { aws = aws.euw1 }
  vpc_cidr = "10.30.0.0/16"
  table_name = module.dynamodb.dynamodb_name
}