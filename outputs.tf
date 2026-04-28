output "region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value = {
    for key, subnet in aws_subnet.public : key => subnet.id
  }
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
