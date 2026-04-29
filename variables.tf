variable "aws_region" {
  description = "AWS region for MediaConnect resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "mediaconnect-interop"
}

# VPC Configuration - Mode Selection
variable "use_existing_vpc" {
  description = "Set to true to use an existing VPC, false to create a new one"
  type        = bool
  default     = false
}

# Variables for EXISTING VPC (used when use_existing_vpc = true)
variable "existing_vpc_id" {
  description = "ID of existing VPC (required when use_existing_vpc = true)"
  type        = string
  default     = null
}

variable "existing_subnet_ids" {
  description = "Map of existing subnet IDs to use for MediaConnect (required when use_existing_vpc = true)"
  type        = map(string)
  default     = {}
  # Example:
  # {
  #   "subnet-1" = "subnet-0abc123def456"
  #   "subnet-2" = "subnet-0def456abc123"
  # }
}

# Variables for NEW VPC (used when use_existing_vpc = false)
variable "vpc_cidr" {
  description = "CIDR block for VPC (only used when creating new VPC)"
  type        = string
  default     = null
}

variable "public_subnets" {
  description = "Map of public subnets for MediaConnect VPC interfaces (only used when creating new VPC)"
  type = map(object({
    cidr = string
    az   = string
  }))
  default = {}
}

variable "private_subnets" {
  description = "Map of private subnets (optional, for future use, only used when creating new VPC)"
  type = map(object({
    cidr = string
    az   = string
  }))
  default = {}
}

# Common variables (used in both modes)
variable "allowed_inbound_cidr" {
  description = "CIDR block allowed for inbound traffic to MediaConnect"
  type        = string
}

variable "mediaconnect_flows" {
  description = "Map of MediaConnect flows with their configurations"
  type = map(object({
    description       = optional(string, "")
    availability_zone = optional(string, null)
    subnet_key        = string # Reference to subnet key
    flow_size         = optional(string, "LARGE") # "MEDIUM", "LARGE", "LARGE_4X"

    source = object({
      name               = string
      description        = optional(string, "")
      protocol           = string # "ndi-speed-hq", "rtp", "rtmp", "srt-listener", "srt-caller", "zixi-push"
      ingest_port        = optional(number, null)
      whitelist_cidr     = optional(string, null)
      stream_id          = optional(string, null)
      max_bitrate        = optional(number, null)
      max_latency        = optional(number, null)
      vpc_interface_name = optional(string, null)
      ndi_source_name    = optional(string, null) # For NDI: the specific NDI source name to use
    })

    # NDI Configuration (only required for NDI sources)
    ndi_config = optional(object({
      ndi_state    = optional(string, "ENABLED")
      machine_name = optional(string, null) # Auto-generated if not specified
      ndi_discovery_servers = list(object({
        discovery_server_address = string
        discovery_server_port    = optional(number, 5959)
        vpc_interface_adapter    = string # VPC interface name
      }))
    }), null)

    # Encoding Configuration (optional)
    encoding_config = optional(object({
      encoding_profile  = optional(string, "DISTRIBUTION_H264_DEFAULT")
      video_max_bitrate = optional(number, 20000000)
    }), null)

    outputs = optional(list(object({
      name               = string
      description        = optional(string, "")
      protocol           = string
      destination        = optional(string, null)
      port               = number
      stream_id          = optional(string, null)
      max_latency        = optional(number, null)
      smoothing_latency  = optional(number, null)
      vpc_interface_name = optional(string, null)
      # Encryption for transit to router (optional)
      encryption = optional(object({
        encryption_key_type = string # "static-key" or "srt-password"
        # Use either automatic or secrets_manager
        automatic = optional(string, null) # "ENABLED" for automatic key management
        secrets_manager = optional(object({
          role_arn   = string
          secret_arn = string
        }), null)
      }), null)
    })), [])
  }))
  default = {}
}
