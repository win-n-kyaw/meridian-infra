output "nomad_server_public_ips" {
  description = "Public IPs of Nomad server instances"
  value       = aws_instance.nomad_server[*].public_ip
}

output "nomad_server_private_ips" {
  description = "Private IPs of Nomad server instances (VPC)"
  value       = aws_instance.nomad_server[*].private_ip
}

output "nomad_server_instance_ids" {
  description = "Instance IDs of Nomad server instances"
  value       = aws_instance.nomad_server[*].id
}

output "ops_public_ip" {
  description = "Public IP of the ops VM"
  value       = aws_instance.ops.public_ip
}

output "ops_private_ip" {
  description = "Private IP of the ops VM (VPC)"
  value       = aws_instance.ops.private_ip
}

output "ops_instance_id" {
  description = "Instance ID of the ops VM"
  value       = aws_instance.ops.id
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_instance_id" {
  description = "Instance ID of the bastion host"
  value       = aws_instance.bastion.id
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.meridian.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = aws_subnet.private.id
}

output "prometheus_volume_id" {
  description = "ID of the Prometheus EBS volume"
  value       = aws_ebs_volume.prometheus_data.id
}

output "ssh_config" {
  description = "SSH config snippet for connecting via bastion"
  value       = <<-EOT
    # Add to ~/.ssh/config
    Host bastion-meridian
      HostName ${aws_instance.bastion.public_ip}
      User ubuntu
      IdentityFile ~/.ssh/meridian

    Host nomad-server-*
      ProxyJump bastion-meridian
      User ubuntu
      IdentityFile ~/.ssh/meridian

    %{for i, ip in aws_instance.nomad_server[*].private_ip~}
    Host nomad-server-${i + 1}
      HostName ${ip}
    %{endfor~}

    Host ops-1
      HostName ${aws_instance.ops.private_ip}
      ProxyJump bastion-meridian
      User ubuntu
      IdentityFile ~/.ssh/meridian
  EOT
}
