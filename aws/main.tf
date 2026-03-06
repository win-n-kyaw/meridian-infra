terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.35.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

# ---------- Data Sources ----------

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu_arm" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

data "aws_ami" "ubuntu_amd" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# ---------- Locals ----------

locals {
  common_tags = merge({
    project = "meridian"
    phase   = "1"
    managed = "terraform"
  }, var.extra_tags)

  az_names    = data.aws_availability_zones.available.names
  az_count    = length(local.az_names)
  selected_az = local.az_names[var.availability_zone_index % local.az_count]
}
