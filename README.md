# MediaConnect Infrastructure - OpenTofu Project

Infrastructure as Code for AWS MediaConnect using OpenTofu - VPC-based deployment with dynamic, scalable flow management.

## Prerequisites

- [OpenTofu](https://opentofu.org/) >= 1.6.0
- AWS CLI configured with appropriate credentials
- AWS account with MediaConnect and VPC permissions

## Project Structure

```
.
├── main.tf                    # Main configuration and provider setup
├── variables.tf               # Input variables and flow structure definitions
├── vpc.tf                     # VPC, subnets, security groups
├── iam.tf                     # IAM roles for MediaConnect VPC access
├── mediaconnect.tf            # MediaConnect flows, VPC interfaces, outputs
├── outputs.tf                 # Output values (VPC info, flow details, IPs)
├── flows.auto.tfvars          # Flow configurations (dynamically scalable)
├── terraform.tfvars.example   # Example variable values
└── README.md                  # This file
```

## Architecture

This setup creates a **VPC-based MediaConnect deployment**:

- **VPC**: Dedicated VPC with public subnets across multiple AZs
- **MediaConnect Flows**: Each flow has a VPC interface (ENI) in your VPC
- **Security**: Security groups control inbound/outbound traffic
- **Scalability**: Add unlimited flows and outputs by editing configuration

### VPC Architecture

```
VPC (10.0.0.0/16)
├── Public Subnet 1 (10.0.1.0/24) - us-east-1a
│   └── MediaConnect VPC Interface(s)
├── Public Subnet 2 (10.0.2.0/24) - us-east-1b
│   └── MediaConnect VPC Interface(s)
└── Internet Gateway
```

## Getting Started

### 1. Copy the example variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

### 2. Edit `terraform.tfvars` to configure VPC settings

Review and customize:

- VPC CIDR block
- Public subnets (CIDR and availability zones)
- Allowed inbound CIDR for security

### 3. Edit `flows.auto.tfvars` to configure your flows

See the examples in the file - each flow needs:

- A `subnet_key` to place the VPC interface
- Source configuration (protocol, port, etc.)
- List of outputs

### 4. Initialize OpenTofu:

```bash
tofu init
```

### 5. Plan the infrastructure:

```bash
tofu plan
```

### 6. Apply the infrastructure:

```bash
tofu apply
```

## Adding Flows, Inputs, and Outputs

The infrastructure is fully dynamic! Just edit `flows.auto.tfvars` to add/remove flows.

### Example: Add a New VPC-based Flow

```hcl
mediaconnect_flows = {
  "my-new-flow" = {
    description       = "Description of my flow"
    availability_zone = "us-east-1a"
    subnet_key        = "subnet-1"  # Which public subnet to use

    source = {
      name           = "my-source"
      description    = "My input source"
      protocol       = "rtmp"        # or "srt-caller", "srt-listener", "rtp"
      ingest_port    = 1935
      whitelist_cidr = "0.0.0.0/0"
      max_latency    = 2000
    }

    outputs = [
      {
        name               = "output-1"
        description        = "First output"
        protocol           = "srt-listener"
        destination        = "10.0.1.100"  # Private IP in VPC
        port               = 5000
        vpc_interface_name = "my-new-flow-vpc-interface"
      },
      {
        name               = "output-2"
        description        = "Second output"
        protocol           = "rtp"
        destination        = "10.0.1.101"  # Private IP in VPC
        port               = 5004
        vpc_interface_name = "my-new-flow-vpc-interface"
      }
      # Add as many outputs as needed!
    ]
  }

  # Add more flows by adding another block!
}
```

### Supported Protocols

**Source Protocols:**

- `rtmp` - RTMP push
- `srt-caller` - SRT caller mode
- `srt-listener` - SRT listener mode
- `rtp` - RTP
- `zixi-push` - Zixi push

**Output Protocols:**

- `srt-listener` - SRT listener
- `srt-caller` - SRT caller
- `rtp` - RTP
- `rtp-fec` - RTP with FEC
- `zixi-push` - Zixi push
- `zixi-pull` - Zixi pull

## VPC Configuration

Configure your VPC in `terraform.tfvars`:

- **VPC CIDR**: Default `10.0.0.0/16`
- **Public Subnets**: Default includes 2 subnets across different AZs
  - `subnet-1`: `10.0.1.0/24` in `us-east-1a`
  - `subnet-2`: `10.0.2.0/24` in `us-east-1b`

### Add More Subnets

Edit `terraform.tfvars` to add more subnets:

```hcl
public_subnets = {
  "subnet-1" = { cidr = "10.0.1.0/24", az = "us-east-1a" }
  "subnet-2" = { cidr = "10.0.2.0/24", az = "us-east-1b" }
  "subnet-3" = { cidr = "10.0.3.0/24", az = "us-east-1c" }  # Add more!
}
```

## Security Groups

The security group allows:

- **RTMP**: TCP 1935
- **SRT**: UDP 5000-5999
- **RTP**: UDP 5004-5005
- **Zixi**: UDP 2088-2089
- **All outbound** traffic

Modify `vpc.tf` to adjust security rules.

## Scaling

The infrastructure automatically scales based on what you define in `flows.auto.tfvars`:

- Want 1 flow with 10 outputs? Just add 10 output blocks
- Want 50 flows? Just add 50 flow blocks
- Each flow automatically gets its own VPC interface
- No code changes needed - just add to the configuration!

## Output Information

After applying, you'll get:

- **VPC details**: VPC ID, CIDR, subnet IDs
- **Flow details**: ARNs, IDs, status, ingest IPs
- **VPC interfaces**: ENI IDs for each flow
- **Security group ID**

View outputs:

```bash
tofu output

# Get just flow info
tofu output flows

# Get VPC info
tofu output vpc_id
```

## Important Notes

### VPC vs Public Internet Flows

This setup uses **VPC interfaces**, which means:

- ✅ Flows are inside your VPC (private networking)
- ✅ Better security and control
- ✅ Can communicate with other VPC resources
- ❌ Requires VPC setup (this project handles it)
- ❌ Uses ENIs (counts against ENI limits)

### IAM Permissions

The setup automatically creates an IAM role that allows MediaConnect to:

- Create and manage network interfaces in your VPC
- Access the specified subnets and security groups

### Cost Considerations

- MediaConnect charges per flow and data transfer
- VPC interfaces (ENIs) have no additional cost
- NAT Gateways (if you add private subnets with NAT) have hourly charges

## Clean Up

To destroy all resources:

```bash
tofu destroy
```

**Warning**: This will delete:

- All MediaConnect flows and outputs
- VPC interfaces
- The VPC and all subnets
- Security groups
- IAM roles

## Troubleshooting

### Flow won't start

- Check security group rules allow your source IP
- Verify the subnet has internet gateway routing
- Check IAM role has correct permissions

### Can't reach outputs

- Ensure destination IPs are reachable from the VPC
- Check VPC routing tables
- Verify output security group rules

### VPC interface creation fails

- Check IAM role permissions
- Verify subnet has available IPs
- Ensure you're within ENI limits for your account

## Next Steps

1. **Configure your video encoder** with the source ingest IP (from `tofu output flows`)
2. **Set up monitoring** - Consider adding CloudWatch alarms
3. **Add CloudWatch Logs** - Enable flow logging for troubleshooting
4. **Consider encryption** - Add encryption blocks to outputs if needed
