output "region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "vpc_id" {
  description = "VPC ID (either existing or newly created)"
  value       = local.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = var.use_existing_vpc ? data.aws_vpc.existing[0].cidr_block : aws_vpc.main[0].cidr_block
}

output "subnet_ids" {
  description = "Subnet IDs used for MediaConnect (either existing or newly created)"
  value       = local.subnet_ids
}

output "security_group_id" {
  description = "MediaConnect security group ID"
  value       = aws_security_group.mediaconnect.id
}

output "flows" {
  description = "MediaConnect flow details"
  value = {
    for key, flow in awscc_mediaconnect_flow.flows : key => {
      arn                   = flow.flow_arn
      flow_id               = flow.id
      name                  = flow.name
      source_ingest_ip      = try(flow.source.ingest_ip, null)
      source_arn            = try(flow.source.source_arn, null)
      vpc_interface_name    = try(flow.vpc_interfaces[0].name, null)
      vpc_interface_eni_ids = try(flow.vpc_interfaces[0].network_interface_ids, [])
    }
  }
}

output "outputs" {
  description = "MediaConnect flow outputs"
  value = {
    for key, output in awscc_mediaconnect_flow_output.outputs : key => {
      output_arn = output.output_arn
      name       = output.name
    }
  }
}
