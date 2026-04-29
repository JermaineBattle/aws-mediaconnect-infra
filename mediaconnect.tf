# MediaConnect Flows with VPC Interfaces
# NOTE: NDI flows are created via AWS CLI (see ndi_flows resource below)
resource "awscc_mediaconnect_flow" "flows" {
  for_each = {
    for key, flow in var.mediaconnect_flows :
    key => flow
    if !contains(["ndi-speed-hq", "ndi-speed-hx"], flow.source.protocol)
  }

  name              = "${var.project_name}-${each.key}-${var.environment}"
  availability_zone = each.value.availability_zone

  # VPC Interface configuration
  vpc_interfaces = [{
    name               = "${each.key}-vpc-interface"
    role_arn           = aws_iam_role.mediaconnect.arn
    security_group_ids = [aws_security_group.mediaconnect.id]
    subnet_id          = local.subnet_ids[each.value.subnet_key]
  }]

  # Source configuration - only include non-null values
  # For NDI, use "srt-listener" as base protocol since NDI isn't accepted at source level
  source = merge(
    {
      name        = each.value.source.name
      description = each.value.source.description

      # Protocol at source level - use srt-listener for NDI as workaround
      protocol = contains(["ndi-speed-hq", "ndi-speed-hx"], each.value.source.protocol) ? "srt-listener" : each.value.source.protocol

      # Transport with actual protocol (supports all protocols including NDI)
      transport = {
        protocol = each.value.source.protocol
      }

      # VPC interface name (for VPC sources)
      vpc_interface_name = each.value.source.vpc_interface_name != null ? each.value.source.vpc_interface_name : "${each.key}-vpc-interface"
    },
    # Only include optional fields if they're not null
    each.value.source.ingest_port != null ? { ingest_port = each.value.source.ingest_port } : {},
    each.value.source.whitelist_cidr != null ? { whitelist_cidr = each.value.source.whitelist_cidr } : {},
    each.value.source.stream_id != null ? { stream_id = each.value.stream_id } : {},
    each.value.source.max_bitrate != null ? { max_bitrate = each.value.source.max_bitrate } : {},
    each.value.source.max_latency != null ? { max_latency = each.value.source.max_latency } : {}
  )

}

# Post-creation configuration via AWS CLI (for non-NDI flows only)
# NDI flows are already configured by ndi_flows resource
resource "null_resource" "flow_configuration" {
  for_each = {
    for key, flow in var.mediaconnect_flows :
    key => flow
    if !contains(["ndi-speed-hq", "ndi-speed-hx"], flow.source.protocol)
  }

  # Trigger re-run if configuration changes
  triggers = {
    flow_arn        = awscc_mediaconnect_flow.flows[each.key].flow_arn
    flow_size       = each.value.flow_size
    ndi_config      = jsonencode(each.value.ndi_config)
    encoding_config = jsonencode(each.value.encoding_config)
  }

  # Configure flow size, NDI, and encoding via AWS CLI
  provisioner "local-exec" {
    command = <<-EOT
      # Update flow size
      aws mediaconnect update-flow \
        --flow-arn "${awscc_mediaconnect_flow.flows[each.key].flow_arn}" \
        --flow-size "${each.value.flow_size}" \
        --region ${var.aws_region}

      ${each.value.ndi_config != null ? <<-NDI
      # Configure NDI
      aws mediaconnect update-flow \
        --flow-arn "${awscc_mediaconnect_flow.flows[each.key].flow_arn}" \
        --ndi-config '{
          "NdiState": "${each.value.ndi_config.ndi_state}",
          ${each.value.ndi_config.machine_name != null ? "\"MachineName\": \"${each.value.ndi_config.machine_name}\"," : ""}
          "NdiDiscoveryServers": [
            ${join(",", [for server in each.value.ndi_config.ndi_discovery_servers : "{\"DiscoveryServerAddress\": \"${server.discovery_server_address}\", \"DiscoveryServerPort\": ${server.discovery_server_port}, \"VpcInterfaceAdapter\": \"${server.vpc_interface_adapter}\"}"])}
          ]
        }' \
        --region ${var.aws_region}
      NDI
      : ""}

      ${each.value.encoding_config != null ? <<-ENC
      # Configure encoding
      aws mediaconnect update-flow \
        --flow-arn "${awscc_mediaconnect_flow.flows[each.key].flow_arn}" \
        --encoding-config '{
          "EncodingProfile": "${each.value.encoding_config.encoding_profile}",
          "VideoMaxBitrate": ${each.value.encoding_config.video_max_bitrate}
        }' \
        --region ${var.aws_region}
      ENC
      : ""}
    EOT
  }

  depends_on = [awscc_mediaconnect_flow.flows]
}

################################################################################
# NDI Flow Creation via AWS CLI
# The awscc provider cannot create NDI sources; Use AWS CLI directly
################################################################################

resource "null_resource" "ndi_flows" {
  for_each = {
    for key, flow in var.mediaconnect_flows :
    key => flow
    if contains(["ndi-speed-hq", "ndi-speed-hx"], flow.source.protocol)
  }

  triggers = {
    flow_name       = "${var.project_name}-${each.key}-${var.environment}"
    source_protocol = each.value.source.protocol
    ndi_config      = jsonencode(each.value.ndi_config)
    flow_size       = each.value.flow_size
    vpc_interface   = "${each.key}-vpc-interface"
    aws_region      = var.aws_region
    flow_key        = each.key
  }

  # Create NDI flow via AWS CLI
  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e

      FLOW_NAME="${var.project_name}-${each.key}-${var.environment}"

      echo "Creating NDI flow: $FLOW_NAME"

      # Create the flow with NDI source (all config at creation time)
      FLOW_ARN=$(aws mediaconnect create-flow \
        --name "$FLOW_NAME" \
        --availability-zone "${each.value.availability_zone}" \
        --flow-size "${each.value.flow_size}" \
        --source '{
          "Name": "${each.value.source.name}",
          "Description": "${each.value.source.description}",
          "Protocol": "${each.value.source.protocol}",
          "NdiSourceSettings": {
            ${each.value.source.ndi_source_name != null ? "\"SourceName\": \"${each.value.source.ndi_source_name}\"" : ""}
          }
        }' \
        --vpc-interfaces '[{
          "Name": "${each.key}-vpc-interface",
          "RoleArn": "${aws_iam_role.mediaconnect.arn}",
          "SecurityGroupIds": ["${aws_security_group.mediaconnect.id}"],
          "SubnetId": "${local.subnet_ids[each.value.subnet_key]}"
        }]' \
        --ndi-config '{
          "NdiState": "${each.value.ndi_config.ndi_state}",
          ${each.value.ndi_config.machine_name != null ? "\"MachineName\": \"${each.value.ndi_config.machine_name}\"," : ""}
          "NdiDiscoveryServers": [
            ${join(",", [for server in each.value.ndi_config.ndi_discovery_servers : "{\"DiscoveryServerAddress\": \"${server.discovery_server_address}\", \"DiscoveryServerPort\": ${server.discovery_server_port}, \"VpcInterfaceAdapter\": \"${server.vpc_interface_adapter}\"}"])}
          ]
        }' \
        --encoding-config '{
          "EncodingProfile": "${each.value.encoding_config.encoding_profile}",
          "VideoMaxBitrate": ${each.value.encoding_config.video_max_bitrate}
        }' \
        --region ${var.aws_region} \
        --query 'Flow.FlowArn' \
        --output text)

      echo "Flow created with ARN: $FLOW_ARN"

      echo "NDI flow $FLOW_NAME created successfully with ARN: $FLOW_ARN"

      # Save flow ARN to file for destroy provisioner
      echo "$FLOW_ARN" > /tmp/ndi-flow-${each.key}.arn

      # Start the flow
      echo "Starting flow..."
      aws mediaconnect start-flow \
        --flow-arn "$FLOW_ARN" \
        --region ${var.aws_region}

      echo "Flow started and is now ACTIVE"

      # Create outputs for this NDI flow
      ${length(each.value.outputs) > 0 ? <<-OUTPUTS
      echo "Creating outputs for NDI flow..."
      ${join("\n", [for output in each.value.outputs : <<-OUT
      aws mediaconnect add-flow-outputs \
        --flow-arn "$FLOW_ARN" \
        --outputs '[{
          "Name": "${output.name}",
          "Description": "${output.description}",
          "Protocol": "${output.protocol}",
          ${output.destination != null && output.protocol != "srt-listener" ? "\"Destination\": \"${output.destination}\"," : ""}
          "Port": ${output.port},
          "VpcInterfaceAttachment": {
            "VpcInterfaceName": "${output.vpc_interface_name != null ? output.vpc_interface_name : "${each.key}-vpc-interface"}"
          }
        }]' \
        --region ${var.aws_region}
      echo "Output ${output.name} created"
      OUT
      ])}
      OUTPUTS
      : ""}

      echo "NDI flow and outputs configured successfully!"
    EOT
    interpreter = ["bash", "-c"]
  }

  # Delete NDI flow when destroyed
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      #!/bin/bash

      # Read the flow ARN from file
      if [ -f "/tmp/ndi-flow-${self.triggers.flow_key}.arn" ]; then
        FLOW_ARN=$(cat /tmp/ndi-flow-${self.triggers.flow_key}.arn)

        echo "Stopping NDI flow: $FLOW_ARN"
        aws mediaconnect stop-flow \
          --flow-arn "$FLOW_ARN" \
          --region ${self.triggers.aws_region} 2>&1 || echo "Flow already stopped or error stopping"

        # Wait for flow to stop
        echo "Waiting for flow to stop..."
        sleep 15

        echo "Deleting NDI flow: $FLOW_ARN"
        aws mediaconnect delete-flow \
          --flow-arn "$FLOW_ARN" \
          --region ${self.triggers.aws_region} 2>&1

        if [ $? -eq 0 ]; then
          echo "Flow deleted successfully"
        else
          echo "ERROR: Flow deletion failed!"
          exit 1
        fi

        # Wait for ENI to be released
        echo "Waiting for ENI to be released..."
        sleep 20

        # Find and delete the ENI associated with this flow
        echo "Finding and deleting ENI..."
        ENI_IDS=$(aws ec2 describe-network-interfaces \
          --filters "Name=description,Values=*${self.triggers.flow_key}-vpc-interface*" \
          --query 'NetworkInterfaces[*].NetworkInterfaceId' \
          --output text \
          --region ${self.triggers.aws_region})

        if [ -n "$ENI_IDS" ]; then
          for ENI_ID in $ENI_IDS; do
            echo "Deleting ENI: $ENI_ID"
            aws ec2 delete-network-interface \
              --network-interface-id "$ENI_ID" \
              --region ${self.triggers.aws_region} 2>&1 || echo "ENI $ENI_ID already deleted or in use"
            sleep 5
          done
        else
          echo "No ENIs found to delete"
        fi

        rm -f /tmp/ndi-flow-${self.triggers.flow_key}.arn
        echo "NDI flow stopped, deleted, and ENI cleaned up"
      fi
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [
    aws_iam_role.mediaconnect,
    aws_security_group.mediaconnect,
    time_sleep.wait_for_iam
  ]
}

# MediaConnect Flow Outputs (only for non-NDI flows)
# NDI flow outputs are created via AWS CLI in the ndi_flows resource
resource "awscc_mediaconnect_flow_output" "outputs" {
  for_each = merge([
    for flow_key, flow in var.mediaconnect_flows : {
      for idx, output in flow.outputs : "${flow_key}-${output.name}" => {
        flow_arn = awscc_mediaconnect_flow.flows[flow_key].flow_arn
        flow_key = flow_key
        name      = output.name
        protocol  = output.protocol

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
    if !contains(["ndi-speed-hq", "ndi-speed-hx"], flow.source.protocol)
  ]...)

  flow_arn = each.value.flow_arn
  name     = each.value.name
  protocol = each.value.protocol

  # VPC interface attachment
  vpc_interface_attachment = each.value.vpc_interface_attachment

  # Basic output configuration
  # For SRT Listener, don't include destination (it listens for incoming connections)
  destination = each.value.protocol != "srt-listener" ? each.value.destination : null
  port        = each.value.port

  description       = try(each.value.description, null)
  stream_id         = try(each.value.stream_id, null)
  max_latency       = try(each.value.max_latency, null)
  smoothing_latency = try(each.value.smoothing_latency, null)

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
