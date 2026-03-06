# ---------- Block Volume: Prometheus Data (ops-1) ----------

resource "oci_core_volume" "prometheus_data" {
  compartment_id      = var.compartment_id
  availability_domain = local.ad_names[(var.availability_domain_index + var.nomad_server_count) % local.ad_count]
  display_name        = "prometheus-data"
  size_in_gbs         = var.prometheus_volume_size_gb

  freeform_tags = merge(local.common_tags, { role = "monitoring" })
}

resource "oci_core_volume_attachment" "prometheus_data" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.ops.id
  volume_id       = oci_core_volume.prometheus_data.id
  display_name    = "prometheus-data-attachment"
  is_read_only    = false
  device          = "/dev/oracleoci/oraclevdb"
}
