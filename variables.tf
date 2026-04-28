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

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "public_subnets" {
  description = "Map of public subnets for MediaConnect VPC interfaces"
  type = map(object({
    cidr = string
    az   = string
  }))
}

variable "private_subnets" {
  description = "Map of private subnets (optional, for future use)"
  type = map(object({
    cidr = string
    az   = string
  }))
  default = {}
}

variable "allowed_inbound_cidr" {
  description = "CIDR block allowed for inbound traffic to MediaConnect"
  type        = string
}

variable "mediaconnect_flows" {
  description = "Map of MediaConnect flows with their configurations"
  type = map(object({
    description       = optional(string, "")
    availability_zone = optional(string, null)
    subnet_key        = string # Reference to public_subnets key

    source = object({
      name           = string
      description    = optional(string, "")
      protocol       = string
      ingest_port    = optional(number, null)
      whitelist_cidr = optional(string, null)
      stream_id      = optional(string, null)
      max_bitrate    = optional(number, null)
      max_latency    = optional(number, 2000)
    })

    outputs = optional(list(object({
      name               = string
      description        = optional(string, "")
      protocol           = string
      destination        = optional(string, null)
      port               = number
      stream_id          = optional(string, null)
      max_latency        = optional(number, null)
      smoothing_latency  = optional(number, 0)
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
