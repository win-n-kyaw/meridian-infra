# ---------- Public Subnet Security List ----------

resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.meridian.id
  display_name   = "meridian-public-sl"

  # --- Egress: allow all outbound ---
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }

  # --- Ingress: SSH ---
  ingress_security_rules {
    protocol  = "6" # TCP
    source    = var.ssh_admin_cidr
    stateless = false

    tcp_options {
      min = 22
      max = 22
    }
  }

  # --- Ingress: WireGuard (Netmaker) ---
  ingress_security_rules {
    protocol  = "17" # UDP
    source    = "0.0.0.0/0"
    stateless = false

    udp_options {
      min = 51820
      max = 51820
    }
  }

  # --- Ingress: ICMP (for network diagnostics) ---
  ingress_security_rules {
    protocol  = "1" # ICMP
    source    = var.vcn_cidr
    stateless = false
  }

  freeform_tags = local.common_tags
}

# ---------- Private Subnet Security List ----------

resource "oci_core_security_list" "private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.meridian.id
  display_name   = "meridian-private-sl"

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }

  # Allow all traffic from within VCN
  ingress_security_rules {
    protocol  = "all"
    source    = var.vcn_cidr
    stateless = false
  }

  freeform_tags = local.common_tags
}

# ---------- NSG: Nomad Servers ----------

resource "oci_core_network_security_group" "nomad" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.meridian.id
  display_name   = "meridian-nomad-nsg"

  freeform_tags = merge(local.common_tags, { role = "nomad" })
}

# Nomad HTTP API (4646/TCP) — from WireGuard mesh
resource "oci_core_network_security_group_security_rule" "nomad_http" {
  network_security_group_id = oci_core_network_security_group.nomad.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = var.wireguard_cidr
  source_type               = "CIDR_BLOCK"
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = 4646
      max = 4646
    }
  }
}

# Nomad RPC (4647/TCP) — server-to-server + client-to-server
resource "oci_core_network_security_group_security_rule" "nomad_rpc" {
  network_security_group_id = oci_core_network_security_group.nomad.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = var.wireguard_cidr
  source_type               = "CIDR_BLOCK"
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = 4647
      max = 4647
    }
  }
}

# Nomad Serf gossip (4648/TCP)
resource "oci_core_network_security_group_security_rule" "nomad_serf_tcp" {
  network_security_group_id = oci_core_network_security_group.nomad.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = var.wireguard_cidr
  source_type               = "CIDR_BLOCK"
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = 4648
      max = 4648
    }
  }
}

# Nomad Serf gossip (4648/UDP)
resource "oci_core_network_security_group_security_rule" "nomad_serf_udp" {
  network_security_group_id = oci_core_network_security_group.nomad.id
  direction                 = "INGRESS"
  protocol                  = "17" # UDP
  source                    = var.wireguard_cidr
  source_type               = "CIDR_BLOCK"
  stateless                 = false

  udp_options {
    destination_port_range {
      min = 4648
      max = 4648
    }
  }
}

# NSG egress — allow all outbound
resource "oci_core_network_security_group_security_rule" "nomad_egress" {
  network_security_group_id = oci_core_network_security_group.nomad.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  stateless                 = false
}

# ---------- NSG: Ops (Monitoring) ----------

resource "oci_core_network_security_group" "ops" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.meridian.id
  display_name   = "meridian-ops-nsg"

  freeform_tags = merge(local.common_tags, { role = "ops" })
}

# Prometheus (9090/TCP) — from WireGuard mesh
resource "oci_core_network_security_group_security_rule" "ops_prometheus" {
  network_security_group_id = oci_core_network_security_group.ops.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = var.wireguard_cidr
  source_type               = "CIDR_BLOCK"
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = 9090
      max = 9090
    }
  }
}

# Grafana (3000/TCP) — from WireGuard mesh
resource "oci_core_network_security_group_security_rule" "ops_grafana" {
  network_security_group_id = oci_core_network_security_group.ops.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = var.wireguard_cidr
  source_type               = "CIDR_BLOCK"
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = 3000
      max = 3000
    }
  }
}

# Loki (3100/TCP) — from WireGuard mesh
resource "oci_core_network_security_group_security_rule" "ops_loki" {
  network_security_group_id = oci_core_network_security_group.ops.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = var.wireguard_cidr
  source_type               = "CIDR_BLOCK"
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = 3100
      max = 3100
    }
  }
}

# Netmaker admin UI + API (8443/TCP) — from WireGuard mesh
resource "oci_core_network_security_group_security_rule" "ops_netmaker" {
  network_security_group_id = oci_core_network_security_group.ops.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = var.wireguard_cidr
  source_type               = "CIDR_BLOCK"
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = 8443
      max = 8443
    }
  }
}

# NSG egress — allow all outbound
resource "oci_core_network_security_group_security_rule" "ops_egress" {
  network_security_group_id = oci_core_network_security_group.ops.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  stateless                 = false
}
