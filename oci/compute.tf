# ---------- Nomad Server Instances (ARM A1 Flex × 3) ----------

resource "oci_core_instance" "nomad_server" {
  count               = var.nomad_server_count
  compartment_id      = var.compartment_id
  availability_domain = local.ad_names[(var.availability_domain_index + count.index) % local.ad_count]
  display_name        = "nomad-server-${count.index + 1}"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.arm_ocpus
    memory_in_gbs = var.arm_memory_gb
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_arm.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_size_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    display_name     = "nomad-server-${count.index + 1}-vnic"
    nsg_ids          = [oci_core_network_security_group.nomad.id]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile(
      "${path.module}/cloud-init/nomad-server.yaml",
      { server_index = count.index + 1 }
    ))
  }

  freeform_tags = merge(local.common_tags, {
    role = "nomad-server"
    name = "nomad-server-${count.index + 1}"
  })

  lifecycle {
    ignore_changes = [source_details[0].source_id]
  }
}

# ---------- Ops Instance (ARM A1 Flex × 1) ----------

resource "oci_core_instance" "ops" {
  compartment_id      = var.compartment_id
  availability_domain = local.ad_names[(var.availability_domain_index + var.nomad_server_count) % local.ad_count]
  display_name        = "ops-1"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.arm_ocpus
    memory_in_gbs = var.arm_memory_gb
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_arm.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_size_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    display_name     = "ops-1-vnic"
    nsg_ids          = [oci_core_network_security_group.ops.id]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile(
      "${path.module}/cloud-init/ops.yaml",
      {}
    ))
  }

  freeform_tags = merge(local.common_tags, {
    role = "ops"
    name = "ops-1"
  })

  lifecycle {
    ignore_changes = [source_details[0].source_id]
  }
}

# ---------- Bastion Instance (AMD E2.1 Micro × 1) ----------

resource "oci_core_instance" "bastion" {
  compartment_id      = var.compartment_id
  availability_domain = local.ad_names[(var.availability_domain_index + var.nomad_server_count + 1) % local.ad_count]
  display_name        = "bastion-1"
  shape               = "VM.Standard.E2.1.Micro"

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_amd.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_size_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    display_name     = "bastion-1-vnic"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile(
      "${path.module}/cloud-init/bastion.yaml",
      {}
    ))
  }

  freeform_tags = merge(local.common_tags, {
    role = "bastion"
    name = "bastion-1"
  })

  lifecycle {
    ignore_changes = [source_details[0].source_id]
  }
}
