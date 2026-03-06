# ---------- VCN ----------

resource "oci_core_vcn" "meridian" {
  compartment_id = var.compartment_id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "meridian-vcn"
  dns_label      = "meridian"

  freeform_tags = merge(local.common_tags, { role = "network" })
}

# ---------- Internet Gateway ----------

resource "oci_core_internet_gateway" "meridian" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.meridian.id
  display_name   = "meridian-igw"
  enabled        = true

  freeform_tags = local.common_tags
}

# ---------- Route Tables ----------

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.meridian.id
  display_name   = "meridian-public-rt"

  route_rules {
    network_entity_id = oci_core_internet_gateway.meridian.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }

  freeform_tags = local.common_tags
}

# ---------- Subnets ----------

resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.meridian.id
  cidr_block                 = var.public_subnet_cidr
  display_name               = "meridian-public"
  dns_label                  = "pub"
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  prohibit_public_ip_on_vnic = false

  freeform_tags = local.common_tags
}

resource "oci_core_subnet" "private" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.meridian.id
  cidr_block                 = var.private_subnet_cidr
  display_name               = "meridian-private"
  dns_label                  = "priv"
  route_table_id             = oci_core_route_table.public.id # uses IGW for now; swap to NAT GW if needed
  security_list_ids          = [oci_core_security_list.private.id]
  prohibit_public_ip_on_vnic = true

  freeform_tags = local.common_tags
}
