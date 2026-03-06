locals {
  effective_key_name = var.create_key_pair ? aws_key_pair.meridian[0].key_name : var.key_pair_name
}

resource "aws_key_pair" "meridian" {
  count      = var.create_key_pair ? 1 : 0
  key_name   = var.key_pair_name
  public_key = var.ssh_public_key

  tags = merge(local.common_tags, {
    Name = var.key_pair_name
  })
}

resource "aws_instance" "nomad_server" {
  count         = var.nomad_server_count
  ami           = data.aws_ami.ubuntu_arm.id
  instance_type = var.nomad_instance_type
  subnet_id     = aws_subnet.public.id

  vpc_security_group_ids = [
    aws_security_group.instance_base.id,
    aws_security_group.nomad.id
  ]

  key_name                    = local.effective_key_name
  associate_public_ip_address = true
  user_data = templatefile("${path.module}/cloud-init/nomad-server.yaml", {
    server_index = count.index + 1
  })

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = var.root_volume_size_gb
    volume_type = "gp3"
  }

  tags = merge(local.common_tags, {
    Name = "nomad-server-${count.index + 1}"
    role = "nomad-server"
  })

  lifecycle {
    ignore_changes = [ami]
  }
}

resource "aws_instance" "ops" {
  ami           = data.aws_ami.ubuntu_arm.id
  instance_type = var.ops_instance_type
  subnet_id     = aws_subnet.public.id

  vpc_security_group_ids = [
    aws_security_group.instance_base.id,
    aws_security_group.ops.id
  ]

  key_name                    = local.effective_key_name
  associate_public_ip_address = true
  user_data                   = templatefile("${path.module}/cloud-init/ops.yaml", {})

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = var.root_volume_size_gb
    volume_type = "gp3"
  }

  tags = merge(local.common_tags, {
    Name = "ops-1"
    role = "ops"
  })

  lifecycle {
    ignore_changes = [ami]
  }
}

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.ubuntu_arm.id
  instance_type = var.bastion_instance_type
  subnet_id     = aws_subnet.public.id

  vpc_security_group_ids = [aws_security_group.bastion.id]

  key_name                    = local.effective_key_name
  associate_public_ip_address = true
  user_data                   = templatefile("${path.module}/cloud-init/bastion.yaml", {})

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = var.root_volume_size_gb
    volume_type = "gp3"
  }

  tags = merge(local.common_tags, {
    Name = "bastion-1"
    role = "bastion"
  })

  lifecycle {
    ignore_changes = [ami]
  }
}
