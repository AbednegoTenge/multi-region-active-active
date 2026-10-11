locals {
    alb_arns = {
        "us-east-1" = "${module.region_use1.alb_arn}"
        "us-west-2" = "${module.region_usw2.alb_arn}"
        "eu-west-1" = "${module.region_euw1.alb_arn}"
    }
}


resource "aws_globalaccelerator_accelerator" "this" {
    name = "my-global-accelerator"
    ip_address_type = "IPV4"
    provider = aws.usw2
    enabled = true
}

resource "aws_globalaccelerator_listener" "this" {
    accelerator_arn = aws_globalaccelerator_accelerator.this.id
    protocol = "TCP"
    provider = aws.usw2
    port_range {
        from_port = 80
        to_port = 80
    }
}

resource "aws_globalaccelerator_endpoint_group" "this" {
    for_each = local.alb_arns
    provider = aws.usw2
    listener_arn = aws_globalaccelerator_listener.this.id
    endpoint_group_region = each.key
    endpoint_configuration {
        endpoint_id = each.value
        weight = 100
    }
}

