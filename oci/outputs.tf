# ---------- Nomad Server Outputs ----------

output "nomad_server_public_ips" {
  description = "Public IPs of Nomad server instances"
  value       = oci_core_instance.nomad_server[*].public_ip
}

output "nomad_server_private_ips" {
  description = "Private IPs of Nomad server instances (VCN)"
  value       = oci_core_instance.nomad_server[*].private_ip
}

output "nomad_server_ocids" {
  description = "OCIDs of Nomad server instances"
  value       = oci_core_instance.nomad_server[*].id
}

# ---------- Ops Outputs ----------

output "ops_public_ip" {
  description = "Public IP of the ops VM"
  value       = oci_core_instance.ops.public_ip
}

output "ops_private_ip" {
  description = "Private IP of the ops VM (VCN)"
  value       = oci_core_instance.ops.private_ip
}

output "ops_ocid" {
  description = "OCID of the ops VM"
  value       = oci_core_instance.ops.id
}

# ---------- Bastion Outputs ----------

output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = oci_core_instance.bastion.public_ip
}

output "bastion_ocid" {
  description = "OCID of the bastion host"
  value       = oci_core_instance.bastion.id
}

# ---------- Network Outputs ----------

output "vcn_id" {
  description = "OCID of the VCN"
  value       = oci_core_vcn.meridian.id
}

output "public_subnet_id" {
  description = "OCID of the public subnet"
  value       = oci_core_subnet.public.id
}

output "private_subnet_id" {
  description = "OCID of the private subnet"
  value       = oci_core_subnet.private.id
}

# ---------- Storage Outputs ----------

output "prometheus_volume_id" {
  description = "OCID of the Prometheus block volume"
  value       = oci_core_volume.prometheus_data.id
}

# ---------- SSH Config Helper ----------

output "ssh_config" {
  description = "SSH config snippet for connecting via bastion"
  value       = <<-EOT
    # Add to ~/.ssh/config
    Host bastion-meridian
      HostName ${oci_core_instance.bastion.public_ip}
      User ubuntu
      IdentityFile ~/.ssh/meridian

    Host nomad-server-*
      ProxyJump bastion-meridian
      User ubuntu
      IdentityFile ~/.ssh/meridian

    %{for i, ip in oci_core_instance.nomad_server[*].private_ip~}
    Host nomad-server-${i + 1}
      HostName ${ip}
    %{endfor~}

    Host ops-1
      HostName ${oci_core_instance.ops.private_ip}
      ProxyJump bastion-meridian
      User ubuntu
      IdentityFile ~/.ssh/meridian
  EOT
}
