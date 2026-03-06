# ---------- OCI Authentication ----------

variable "tenancy_ocid" {
  description = "OCID of the OCI tenancy"
  type        = string
}

variable "user_ocid" {
  description = "OCID of the OCI user for API access"
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint of the OCI API signing key"
  type        = string
}

variable "private_key_path" {
  description = "Path to the OCI API private key PEM file"
  type        = string
  default     = "~/.oci/oci.pem"
}

variable "compartment_id" {
  description = "OCID of the compartment to create resources in"
  type        = string
}

variable "region" {
  description = "OCI region (must be home region for Always Free)"
  type        = string
  default     = "ap-singapore-1"
}

variable "availability_domain_index" {
  description = "0-based AD index to start placement from (instances are spread across ADs)."
  type        = number
  default     = 0
}

# ---------- SSH ----------

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
}

variable "ssh_admin_cidr" {
  description = "CIDR block allowed to SSH into bastion (your IP/32 or office range)"
  type        = string
  default     = "0.0.0.0/0"
}

# ---------- Network ----------

variable "vcn_cidr" {
  description = "CIDR block for the VCN"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet (reserved)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "wireguard_cidr" {
  description = "CIDR block for the WireGuard mesh (Netmaker-managed)"
  type        = string
  default     = "10.10.0.0/16"
}

# ---------- Compute ----------

variable "nomad_server_count" {
  description = "Number of Nomad server instances"
  type        = number
  default     = 3
}

variable "arm_ocpus" {
  description = "OCPUs per ARM A1 Flex instance"
  type        = number
  default     = 1
}

variable "arm_memory_gb" {
  description = "Memory in GB per ARM A1 Flex instance"
  type        = number
  default     = 6
}

variable "boot_volume_size_gb" {
  description = "Boot volume size in GB per instance (5 × this must stay <= 200 GB for Always Free)"
  type        = number
  default     = 47
}

variable "prometheus_volume_size_gb" {
  description = "Block volume size in GB for Prometheus data on ops-1"
  type        = number
  default     = 50
}
