# AWS FIS: chaos experiments run from eu-west-1.
# FIS needs a config bucket in the region the experiment starts from.

data "aws_caller_identity" "current" {
  provider = aws.use1
}

resource "aws_s3_bucket" "fis_bucket" {
  provider      = aws.euw1
  bucket        = "abed-fis-config-${data.aws_caller_identity.current.account_id}-euw1"
  force_destroy = true

  tags = {
    Name = "FIS Bucket"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "fis_bucket_encryption" {
  provider = aws.euw1
  bucket   = aws_s3_bucket.fis_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "fis_bucket_public_access_block" {
  provider                = aws.euw1
  bucket                  = aws_s3_bucket.fis_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Role FIS assumes while running an experiment.
data "aws_iam_policy_document" "fis_assume_role" {
  provider = aws.use1
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["fis.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "fis" {
  provider           = aws.use1
  name               = "fis-experiment-role"
  assume_role_policy = data.aws_iam_policy_document.fis_assume_role.json
}

resource "aws_iam_role_policy" "fis" {
  provider = aws.use1
  name     = "fis-lambda-faults"
  role     = aws_iam_role.fis.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "LambdaFaultConfig"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.fis_bucket.arn}/FisConfigs/*"
      },
      {
        Sid      = "FindTargets"
        Effect   = "Allow"
        Action   = ["lambda:GetFunction", "tag:GetResources"]
        Resource = "*"
      },
      {
        Sid    = "PauseDynamoDbReplication"
        Effect = "Allow"
        Action = [
          "dynamodb:PutResourcePolicy",
          "dynamodb:DeleteResourcePolicy",
          "dynamodb:GetResourcePolicy",
          "dynamodb:DescribeTable",
        ]
        Resource = "*"
      },
      {
        Sid    = "DisruptSubnetConnectivity"
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkAcl",
          "ec2:CreateNetworkAclEntry",
          "ec2:CreateTags",
          "ec2:DeleteNetworkAcl",
          "ec2:DescribeManagedPrefixLists",
          "ec2:DescribeNetworkAcls",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:GetManagedPrefixListEntries",
          "ec2:ReplaceNetworkAclAssociation",
        ]
        Resource = "*"
      }
    ]
  })
}

# Targets are picked by tag, never by ARN. Only resources tagged ChaosTarget=true can be hit,
# and an experiment only touches its own region (eu-west-1 here).

# Experiment 1: app layer only. Fail every eu-west-1 Lambda invocation for 5 minutes.
resource "aws_fis_experiment_template" "euw1_lambda_errors" {
  provider    = aws.euw1
  description = "Fail 100% of eu-west-1 Lambda invocations for 5 minutes"
  role_arn    = aws_iam_role.fis.arn

  stop_condition {
    source = "none"
  }

  action {
    name      = "lambda-invocation-errors"
    action_id = "aws:lambda:invocation-error"

    parameter {
      key   = "duration"
      value = "PT5M"
    }
    parameter {
      key   = "invocationPercentage"
      value = "100"
    }
    parameter {
      key   = "preventExecution"
      value = "false"
    }

    target {
      key   = "Functions"
      value = "app"
    }
  }

  target {
    name           = "app"
    resource_type  = "aws:lambda:function"
    selection_mode = "ALL"
    resource_tag {
      key   = "ChaosTarget"
      value = "true"
    }
    resource_tag {
      key   = "Layer"
      value = "app"
    }
  }

  tags = {
    Name = "euw1-lambda-errors"
  }
}

# Experiment 2: full regional outage. Break app, data and network in eu-west-1 at once.
# 15 minutes because DynamoDB may keep replicating for up to 5 minutes after the pause starts.
resource "aws_fis_experiment_template" "euw1_region_outage" {
  provider    = aws.euw1
  description = "Simulate a full eu-west-1 outage: Lambda errors, replication paused, subnets cut off"
  role_arn    = aws_iam_role.fis.arn

  stop_condition {
    source = "none"
  }

  action {
    name      = "app-lambda-errors"
    action_id = "aws:lambda:invocation-error"

    parameter {
      key   = "duration"
      value = "PT15M"
    }
    parameter {
      key   = "invocationPercentage"
      value = "100"
    }
    parameter {
      key   = "preventExecution"
      value = "false"
    }

    target {
      key   = "Functions"
      value = "app"
    }
  }

  action {
    name      = "data-pause-replication"
    action_id = "aws:dynamodb:global-table-pause-replication"

    parameter {
      key   = "duration"
      value = "PT15M"
    }

    target {
      key   = "Tables"
      value = "data"
    }
  }

  action {
    name      = "network-cut-subnets"
    action_id = "aws:network:disrupt-connectivity"

    parameter {
      key   = "duration"
      value = "PT15M"
    }
    parameter {
      key   = "scope"
      value = "all"
    }

    target {
      key   = "Subnets"
      value = "network"
    }
  }

  target {
    name           = "app"
    resource_type  = "aws:lambda:function"
    selection_mode = "ALL"
    resource_tag {
      key   = "ChaosTarget"
      value = "true"
    }
    resource_tag {
      key   = "Layer"
      value = "app"
    }
  }

  target {
    name           = "data"
    resource_type  = "aws:dynamodb:global-table"
    selection_mode = "ALL"
    resource_tag {
      key   = "ChaosTarget"
      value = "true"
    }
    resource_tag {
      key   = "Layer"
      value = "data"
    }
  }

  target {
    name           = "network"
    resource_type  = "aws:ec2:subnet"
    selection_mode = "ALL"
    resource_tag {
      key   = "ChaosTarget"
      value = "true"
    }
    resource_tag {
      key   = "Layer"
      value = "network"
    }
  }

  tags = {
    Name = "euw1-region-outage"
  }
}
