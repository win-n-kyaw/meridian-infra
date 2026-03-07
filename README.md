# meridian-infra

terraform output
bastion_instance_id = "i-0f460f8599f449f5a"
bastion_public_ip = "54.255.222.98"
nomad_server_instance_ids = [
  "i-0126e3cd95b3bd795",
  "i-0f77deca740144381",
  "i-045b9fbb9fd5f0514",
]
nomad_server_private_ips = [
  "10.0.1.20",
  "10.0.1.223",
  "10.0.1.99",
]
nomad_server_public_ips = [
  "3.0.19.225",
  "3.0.56.208",
  "13.215.184.45",
]
ops_instance_id = "i-08943da123c1530f9"
ops_private_ip = "10.0.1.139"
ops_public_ip = "54.179.190.33"
private_subnet_id = "subnet-02754af7b0a538bc3"
prometheus_volume_id = "vol-036957d9874bfc546"
public_subnet_id = "subnet-0affa24434325ef70"
ssh_config = <<EOT
# Add to ~/.ssh/config
Host bastion-meridian
  HostName 54.255.222.98
  User ubuntu
  IdentityFile ~/.ssh/meridian

Host nomad-server-*
  ProxyJump bastion-meridian
  User ubuntu
  IdentityFile ~/.ssh/meridian

    Host nomad-server-1
  HostName 10.0.1.20
    Host nomad-server-2
  HostName 10.0.1.223
    Host nomad-server-3
  HostName 10.0.1.99

Host ops-1
  HostName 10.0.1.139
  ProxyJump bastion-meridian
  User ubuntu
  IdentityFile ~/.ssh/meridian

EOT
vpc_id = "vpc-0253e918c4748e335"