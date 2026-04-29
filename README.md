# MediaConnect Infrastructure Build - OpenTofu Project

Production-ready Infrastructure as Code for AWS MediaConnect using OpenTofu - VPC-based deployment with full NDI support and dynamic, scalable flow management.

## Features

✅ **Full NDI Support** - NDI sources with discovery server integration and automatic source selection  
✅ **Dual VPC Mode** - Create new VPC or use existing VPC infrastructure  
✅ **Auto Lifecycle** - Flows automatically start on creation and stop before deletion  
✅ **Dynamic & Scalable** - Add unlimited flows and outputs via configuration files  
✅ **Multi-Protocol** - NDI, RTP, RTMP, SRT, Zixi support  
✅ **Proper Cleanup** - ENIs automatically cleaned up, no orphaned resources  
✅ **Production Ready** - IAM propagation handling, error recovery, clean destroy 

As of today (4/29/2026), I could not find support from the awscc library for the NDI source addition for MediaConnect. To resolve this issue, I used a combination of awscc for initial flow creation, then finished the configuration with aws-cli.

## Prerequisites

- [OpenTofu](https://opentofu.org/) >= 1.6.0
- AWS CLI configured with appropriate credentials
- AWS account with MediaConnect and VPC permissions

## Project Structure

```
.
├── main.tf                       # Provider configuration (aws + awscc)
├── variables.tf                  # Variable definitions and type structures
├── vpc.tf                        # VPC infrastructure (new or existing)
├── iam.tf                        # IAM roles for MediaConnect VPC access
├── mediaconnect.tf               # MediaConnect flows (Terraform + AWS CLI)
├── outputs.tf                    # Output values (VPC info, flow details)
├── terraform.tfvars.example      # VPC configuration template
├── flows.auto.tfvars.example     # Flow configuration template
└── README.md                     # This file
```

## Architecture

This setup creates a **VPC-based MediaConnect deployment**:

### VPC Architecture
```
VPC (Existing or New)
├── Public Subnet 1 (us-east-1a)
│   └── MediaConnect VPC Interface(s) → ENI
├── Public Subnet 2 (us-east-1b)
│   └── MediaConnect VPC Interface(s) → ENI
├── Internet Gateway
└── Security Groups (MediaConnect protocols)
```

### Flow Lifecycle
```
tofu apply:
  1. Create VPC infrastructure (or use existing)
  2. Create IAM roles
  3. Wait 15s for IAM propagation
  4. Create MediaConnect flows
  5. Start flows (ACTIVE)
  6. Create outputs

tofu destroy:
  1. Stop flows (STANDBY)
  2. Wait for stop to complete
  3. Delete flows
  4. Find and delete ENIs
  5. Delete security groups
  6. Delete VPC resources (if created)
```

## Quick Start

### 1. Copy Configuration Templates

```bash
cp terraform.tfvars.example terraform.tfvars
cp flows.auto.tfvars.example flows.auto.tfvars
```

### 2. Configure VPC Settings

Edit `terraform.tfvars`:

**Option A - Use Existing VPC:**
```hcl
use_existing_vpc = true
aws_region       = "us-east-1"
environment      = "prod"
project_name     = "my-mediaconnect"

existing_vpc_id = "vpc-abc123"
existing_subnet_ids = {
  "subnet-1" = "subnet-abc123"
  "subnet-2" = "subnet-def456"
}

allowed_inbound_cidr = "10.0.0.0/8"
```

**Option B - Create New VPC:**
```hcl
use_existing_vpc = false
aws_region       = "us-east-1"
environment      = "prod"
project_name     = "my-mediaconnect"

vpc_cidr = "10.0.0.0/16"
public_subnets = {
  "subnet-1" = { cidr = "10.0.1.0/24", az = "us-east-1a" }
  "subnet-2" = { cidr = "10.0.2.0/24", az = "us-east-1b" }
}

allowed_inbound_cidr = "0.0.0.0/0"
```

### 3. Configure MediaConnect Flows

Edit `flows.auto.tfvars`:

**NDI Flow Example:**
```hcl
mediaconnect_flows = {
  "ndi-flow-01" = {
    description       = "Production NDI flow"
    availability_zone = "us-east-1a"
    subnet_key        = "subnet-1"
    flow_size         = "LARGE"

    source = {
      name               = "ndi-source-main"
      description        = "Primary NDI source"
      protocol           = "ndi-speed-hq"
      vpc_interface_name = "ndi-flow-01-vpc-interface"
      ndi_source_name    = "ENCODER-01 (Camera 1)"
    }

    ndi_config = {
      ndi_state    = "ENABLED"
      machine_name = null
      ndi_discovery_servers = [{
        discovery_server_address = "10.20.2.56"
        discovery_server_port    = 5959
        vpc_interface_adapter    = "ndi-flow-01-vpc-interface"
      }]
    }

    encoding_config = {
      encoding_profile  = "DISTRIBUTION_H264_DEFAULT"
      video_max_bitrate = 20000000
    }

    outputs = [{
      name               = "srt-output-01"
      description        = "SRT distribution"
      protocol           = "srt-listener"
      port               = 5001
      vpc_interface_name = "ndi-flow-01-vpc-interface"
    }]
  }
}
```

### 4. Deploy

```bash
# Initialize OpenTofu
tofu init

# Preview changes
tofu plan

# Deploy infrastructure
tofu apply
```

### 5. Get Flow Information

```bash
# View all outputs
tofu output

# View specific flow details
tofu output flows

# View VPC information
tofu output vpc_id
```

## Flow Types

### NDI Flows (via AWS CLI)

**Features:**
- Full NDI discovery server integration
- NDI source name selection
- Flow size: LARGE (required)
- Automatic encoding configuration
- Auto-start on creation

**Configuration:**
```hcl
protocol = "ndi-speed-hq"
ndi_source_name = "YOUR-NDI-SOURCE-NAME"
ndi_config = { ... }
encoding_config = { ... }
```

### Standard Flows (via Terraform)

**Supported Protocols:**
- RTP
- RTMP  
- SRT (caller/listener)
- Zixi (push/pull)

**Configuration:**
```hcl
protocol = "rtp"  # or "rtmp", "srt-listener", etc.
ingest_port = 5004
max_latency = 2000
```

## Output Protocols

### SRT Listener
```hcl
protocol    = "srt-listener"
port        = 5001
# No destination - listens for incoming connections
```

### SRT Caller
```hcl
protocol    = "srt-caller"
destination = "192.168.1.100"
port        = 5001
```

### RTP
```hcl
protocol    = "rtp"
destination = "224.0.0.1"
port        = 5004
```

## Scaling

Add flows by adding blocks to `flows.auto.tfvars`:

```hcl
mediaconnect_flows = {
  "flow-01" = { ... }
  "flow-02" = { ... }
  "flow-03" = { ... }
  # Add as many as needed
}
```

Each flow can have unlimited outputs:
```hcl
outputs = [
  { name = "output-1", ... },
  { name = "output-2", ... },
  { name = "output-3", ... },
  # Add as many as needed
]
```

## Security

### Security Groups

Automatically created with rules for:
- **RTMP**: TCP 1935
- **SRT**: UDP 5000-5999
- **RTP**: UDP 5004-5005
- **Zixi**: UDP 2088-2089
- **All outbound** traffic

Restrict `allowed_inbound_cidr` in production.

### IAM Roles

Automatically created with permissions for:
- Create/delete network interfaces
- Describe VPC resources
- Attach to MediaConnect flows

### Encryption

Optional per-output encryption:
```hcl
encryption = {
  encryption_key_type = "static-key"
  automatic           = "ENABLED"
}
```

Or use AWS Secrets Manager:
```hcl
encryption = {
  encryption_key_type = "static-key"
  secrets_manager = {
    role_arn   = "arn:aws:iam::..."
    secret_arn = "arn:aws:secretsmanager:..."
  }
}
```

## Important Notes

### NDI Configuration

**NDI Source Name:** Must match exactly as it appears on the network
- Format: `HOSTNAME (Source Name)`
- Example: `ENCODER-01 (Camera 1)`
- Check your NDI discovery server for available sources

**NDI Discovery Server:** Must be reachable from the VPC subnet
- Configure IP and port
- Default port: 5959

### Flow Size

- **MEDIUM**: Up to 50 transport streams, 400 Mbps aggregate (1.25 Gbps)
- **LARGE**: NDI sources, high-quality, 1080p60, 2.5 Gbps throughput
- **LARGE_4X**: Enhanced processing power, optimized for CDI workflows

### Port Requirements

- Flow-level ports must be unique within each flow
- SRT Listener outputs don't specify `destination`
- Avoid using reserved ports (2077, 2088 for specific protocols)

### IAM Propagation

The setup includes a 15-second wait after IAM role creation to allow AWS to propagate the role across all services. This prevents "unable to assume role" errors on first apply.

### ENI Cleanup

On destroy, the process:
1. Stops all flows
2. Deletes flows  
3. Waits for ENI detachment
4. Explicitly deletes ENIs
5. Then deletes security groups and VPC

This ensures clean teardown with no orphaned resources.

## Outputs

After deployment, you'll see:

```hcl
flows = {
  "ndi-flow-01" = {
    arn              = "arn:aws:mediaconnect:..."
    name             = "mediaconnect-interop-ndi-flow-01-prod"
    status           = "ACTIVE"
    source_ingest_ip = "54.123.45.67"  # Use this to send streams
    vpc_interface_eni_ids = ["eni-abc123"]
  }
}
```

The `source_ingest_ip` is where you send your video streams.

## Troubleshooting

### Flow Creation Fails with IAM Error

**Symptom:** "Unable to assume role" error on first apply  
**Cause:** IAM propagation delay  
**Solution:** Already handled with automatic 15-second wait. If it still fails, run `tofu apply` again.

### Destroy Fails with Security Group Error

**Symptom:** "security group has a dependent object"  
**Cause:** ENI not fully detached  
**Solution:** Already handled with automatic ENI cleanup. If it persists, manually delete ENIs in AWS Console.

### NDI Source Not Found

**Symptom:** Flow created but no NDI source visible  
**Cause:** NDI source name mismatch or discovery server not reachable  
**Solution:** 
- Verify NDI source name matches exactly (case-sensitive)
- Check discovery server IP is reachable from VPC subnet
- Verify discovery server is running

### Flow Won't Start

**Symptom:** Flow status stuck in STANDBY  
**Cause:** VPC configuration or source issues  
**Solution:**
- Check security group allows required ports
- Verify subnet routing to internet gateway
- Check NDI discovery server connectivity

## Cost Considerations

- **MediaConnect Flows**: Per-flow hourly charge + data transfer
- **VPC**: No charge for VPC itself
- **ENIs**: No additional charge
- **Data Transfer**: Standard AWS data transfer rates apply
- **NAT Gateway**: If you add private subnets with NAT, hourly charge applies

## Clean Up

To destroy all resources:

```bash
tofu destroy
```

This will:
1. Stop all flows
2. Delete all flows (waits for completion)
3. Delete all ENIs
4. Delete security groups
5. Delete VPC resources (if created)

**Note:** Actual `terraform.tfvars` and `flows.auto.tfvars` are gitignored - your sensitive data stays local.

## Support

- AWS MediaConnect Documentation: https://docs.aws.amazon.com/mediaconnect/
- OpenTofu Documentation: https://opentofu.org/docs/
- NDI Documentation: https://ndi.video/

## License

This infrastructure code is provided as-is for use with AWS MediaConnect.
