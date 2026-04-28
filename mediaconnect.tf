# MediaConnect Flows with VPC Interfaces
resource "awscc_mediaconnect_flow" "flows" {
  for_each = var.mediaconnect_flows

  name              = "${var.project_name}-${each.key}-${var.environment}"
  availability_zone = each.value.availability_zone

  # VPC Interface configuration
  vpc_interfaces = [{
    name               = "${each.key}-vpc-interface"
    role_arn           = aws_iam_role.mediaconnect.arn
    security_group_ids = [aws_security_group.mediaconnect.id]
    subnet_id          = aws_subnet.public[each.value.subnet_key].id
  }]

  # Source configuration
  source = {
    name               = each.value.source.name
    description        = each.value.source.description
    protocol           = each.value.source.protocol
    ingest_port        = each.value.source.ingest_port
    whitelist_cidr     = each.value.source.whitelist_cidr
    stream_id          = each.value.source.stream_id
    max_bitrate        = each.value.source.max_bitrate
    max_latency        = each.value.source.max_latency
    vpc_interface_name = "${each.key}-vpc-interface"
  }
}

# MediaConnect Flow Outputs
resource "awscc_mediaconnect_flow_output" "outputs" {
  for_each = merge([
    for flow_key, flow in var.mediaconnect_flows : {
      for idx, output in flow.outputs : "${flow_key}-${output.name}" => {
        flow_arn = awscc_mediaconnect_flow.flows[flow_key].flow_arn
        flow_key = flow_key
        name     = output.name
        protocol = output.protocol

        # VPC interface attachment
        vpc_interface_attachment = {
          vpc_interface_name = output.vpc_interface_name != null ? output.vpc_interface_name : "${flow_key}-vpc-interface"
        }

        # Output destination configuration
        destination       = output.destination
        port              = output.port
        description       = output.description
        stream_id         = output.stream_id
        max_latency       = output.max_latency
        smoothing_latency = output.smoothing_latency

        # Encryption if provided
        encryption = output.encryption
      }
    }
  ]...)

  flow_arn = each.value.flow_arn
  name     = each.value.name
  protocol = each.value.protocol

  # VPC interface attachment
  vpc_interface_attachment = each.value.vpc_interface_attachment

  # Basic output configuration
  destination       = each.value.destination
  port              = each.value.port
  description       = try(each.value.description, null)
  stream_id         = try(each.value.stream_id, null)
  max_latency       = try(each.value.max_latency, null)
  smoothing_latency = try(each.value.smoothing_latency, null)

  # Encryption (optional)
  cidr_allow_list = try(each.value.cidr_allow_list, null)

  # Router integration transit encryption (if encryption is defined)
  router_integration_transit_encryption = each.value.encryption != null ? {
    encryption_key_type = each.value.encryption.encryption_key_type
    encryption_key_configuration = each.value.encryption.automatic != null ? {
      automatic = each.value.encryption.automatic
      } : (
      each.value.encryption.secrets_manager != null ? {
        secrets_manager = {
          role_arn   = each.value.encryption.secrets_manager.role_arn
          secret_arn = each.value.encryption.secrets_manager.secret_arn
        }
      } : null
    )
  } : null
}
