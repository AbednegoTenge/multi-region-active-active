output "use1_url" { value = "http://${module.region_use1.alb_dns_name}" }
output "usw2_url" { value = "http://${module.region_usw2.alb_dns_name}" }
output "euw1_url" { value = "http://${module.region_euw1.alb_dns_name}" }
output "global_url" { value = "http://${aws_globalaccelerator_accelerator.this.dns_name}" }