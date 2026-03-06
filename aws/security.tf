resource "aws_security_group" "instance_base" {
  name        = "${var.key_pair_name}-instance-base"
  description = "Base ingress/egress for public Meridian instances."
  vpc_id      = aws_vpc.meridian.id

  ingress {
    description = "SSH admin access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_admin_cidr]
  }

  ingress {
    description = "SSH from VPC (bastion ProxyJump)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "WireGuard/Netmaker"
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ICMP from VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "meridian-instance-base-sg"
  })
}

resource "aws_security_group" "bastion" {
  name        = "${var.key_pair_name}-bastion"
  description = "Bastion SSH access."
  vpc_id      = aws_vpc.meridian.id

  ingress {
    description = "SSH admin access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_admin_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "meridian-bastion-sg"
  })
}

resource "aws_security_group" "nomad" {
  name        = "${var.key_pair_name}-nomad"
  description = "Nomad server ports over WireGuard."
  vpc_id      = aws_vpc.meridian.id

  ingress {
    description = "Nomad HTTP API"
    from_port   = 4646
    to_port     = 4646
    protocol    = "tcp"
    cidr_blocks = [var.wireguard_cidr]
  }

  ingress {
    description = "Nomad RPC"
    from_port   = 4647
    to_port     = 4647
    protocol    = "tcp"
    cidr_blocks = [var.wireguard_cidr]
  }

  ingress {
    description = "Nomad Serf TCP"
    from_port   = 4648
    to_port     = 4648
    protocol    = "tcp"
    cidr_blocks = [var.wireguard_cidr]
  }

  ingress {
    description = "Nomad Serf UDP"
    from_port   = 4648
    to_port     = 4648
    protocol    = "udp"
    cidr_blocks = [var.wireguard_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "meridian-nomad-sg"
    role = "nomad"
  })
}

resource "aws_security_group" "ops" {
  name        = "${var.key_pair_name}-ops"
  description = "Ops stack ports over WireGuard."
  vpc_id      = aws_vpc.meridian.id

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.wireguard_cidr]
  }

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.wireguard_cidr]
  }

  ingress {
    description = "Loki"
    from_port   = 3100
    to_port     = 3100
    protocol    = "tcp"
    cidr_blocks = [var.wireguard_cidr]
  }

  ingress {
    description = "Netmaker admin/API"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = [var.wireguard_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "meridian-ops-sg"
    role = "ops"
  })
}
