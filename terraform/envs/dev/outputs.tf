output "use1_url" { value = "http://${module.region_use1.alb_dns_name}" }
output "usw2_url" { value = "http://${module.region_usw2.alb_dns_name}" }
output "euw1_url" { value = "http://${module.region_euw1.alb_dns_name}" }
output "global_url" { value = "http://${aws_globalaccelerator_accelerator.this.dns_name}" }
output "fis_euw1_template_id" { value = aws_fis_experiment_template.euw1_lambda_errors.id }
output "fis_euw1_outage_template_id" { value = aws_fis_experiment_template.euw1_region_outage.id }
