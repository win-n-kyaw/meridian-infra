variable "aws_profile" {
  description = "Optional AWS CLI profile name."
  type        = string
  default     = null
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "ap-southeast-1"
}

variable "availability_zone_index" {
  description = "0-based AZ index for subnet placement."
  type        = number
  default     = 0
}

# ---------- SSH ----------

variable "ssh_public_key" {
  description = "SSH public key for instance access."
  type        = string
}

variable "ssh_admin_cidr" {
  description = "CIDR block allowed to SSH into bastion (your IP/32 or office range)."
  type        = string
  default     = "0.0.0.0/0"
}

variable "create_key_pair" {
  description = "Create an AWS key pair from ssh_public_key."
  type        = bool
  default     = true
}

variable "key_pair_name" {
  description = "EC2 key pair name to create/use."
  type        = string
  default     = "meridian-key"
}

# ---------- Network ----------

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet (reserved)."
  type        = string
  default     = "10.0.2.0/24"
}

variable "wireguard_cidr" {
  description = "CIDR block for the WireGuard mesh (Netmaker-managed)."
  type        = string
  default     = "10.10.0.0/16"
}

# ---------- Compute ----------

variable "nomad_server_count" {
  description = "Number of Nomad server instances."
  type        = number
  default     = 3
}

variable "nomad_instance_type" {
  description = "Instance type for Nomad server nodes (ARM)."
  type        = string
  default     = "t4g.large"
}

variable "ops_instance_type" {
  description = "Instance type for ops node (ARM)."
  type        = string
  default     = "t4g.large"
}

variable "bastion_instance_type" {
  description = "Instance type for bastion host (x86_64)."
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size_gb" {
  description = "Root volume size in GB per instance."
  type        = number
  default     = 47
}

# ---------- Storage ----------

variable "prometheus_volume_size_gb" {
  description = "EBS volume size in GB for Prometheus data on ops-1."
  type        = number
  default     = 50
}

variable "prometheus_volume_device_name" {
  description = "Linux device path used to attach Prometheus EBS volume."
  type        = string
  default     = "/dev/sdf"
}

variable "extra_tags" {
  description = "Extra tags applied to all resources."
  type        = map(string)
  default     = {}
}
