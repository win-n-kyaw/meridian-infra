
bastion_instance_id = "i-0ea97a1304313839b"
bastion_public_ip = "18.141.13.153"
nomad_server_instance_ids = [
  "i-0a4332a3b2472d4c4",
  "i-0300ddf9b7f3b144d",
  "i-0666f0bab6fbdba02",
]
nomad_server_private_ips = [
  "10.0.1.33",
  "10.0.1.99",
  "10.0.1.68",
]
nomad_server_public_ips = [
  "18.136.123.125",
  "13.213.30.33",
  "13.229.72.208",
]
ops_instance_id = "i-0c43cf42b1606d580"
ops_private_ip = "10.0.1.14"
ops_public_ip = "3.1.222.36"
private_subnet_id = "subnet-014a3e69d74079fd4"
prometheus_volume_id = "vol-08af7c5bbc2ed6b5e"
public_subnet_id = "subnet-0672f3bbaf34ba135"
ssh_config = <<EOT
# Add to ~/.ssh/config
Host bastion-meridian
  HostName 18.141.13.153
  User ubuntu
  IdentityFile ~/.ssh/meridian

Host nomad-server-*
  ProxyJump bastion-meridian
  User ubuntu
  IdentityFile ~/.ssh/meridian

    Host nomad-server-1
  HostName 10.0.1.33
    Host nomad-server-2
  HostName 10.0.1.99
    Host nomad-server-3
  HostName 10.0.1.68

Host ops-1
  HostName 10.0.1.14
  ProxyJump bastion-meridian
  User ubuntu
  IdentityFile ~/.ssh/meridian

EOT
vpc_id = "vpc-08bfbf244f41b966a"