# CLAUDE.md — Project Meridian

## Project Identity

**Name:** Project Meridian
**Purpose:** Migrate a fleet of dockerized application servers from standalone Docker-on-VM to HashiCorp Nomad orchestration, with the control plane hosted on Oracle Cloud Infrastructure (OCI) Always Free tier in Singapore.
**Current Phase:** Phase 1 — Foundation & Proof of Concept
**Owner:** Win (solo engineer, early-career SWE, based in Southeast Asia)
**Started:** March 2026

---

## Quick Context

Meridian manages a fleet of 1 GB RAM VPS instances across multiple small IaaS providers (NOT AWS/Azure/GCP). Each VPS runs a single dockerized application. The fleet is currently ~40 nodes (Alibaba Cloud) scaling to 300. Public IP rotation on any node is a hard requirement. The control plane runs entirely on OCI Always Free ARM instances in Singapore.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│  OCI Singapore (ap-singapore-1) — Always Free   │
│                                                 │
│  nomad-server-1  (A1 Flex, 1C/6GB)             │
│  nomad-server-2  (A1 Flex, 1C/6GB)             │
│  nomad-server-3  (A1 Flex, 1C/6GB)             │
│  ops-1           (A1 Flex, 1C/6GB)             │
│  bastion-1       (E2 Micro, 1/8C/1GB)          │
│                                                 │
│  Services on ops-1:                             │
│    Netmaker, Prometheus, Grafana, Loki,         │
│    Alertmanager                                 │
└───────────────────┬─────────────────────────────┘
                    │ WireGuard mesh (Netmaker)
                    │ CIDR: 10.10.0.0/16
┌───────────────────┴─────────────────────────────┐
│  Multi-Provider Agent Fleet                     │
│  40 nodes (MVP) → 300 nodes (target)            │
│  Each: 1GB RAM VPS, Nomad Client, Docker,       │
│        WireGuard, node_exporter                 │
│  Providers: Alibaba, Tencent, Vultr, Hetzner,   │
│             Contabo, and other small IaaS       │
└─────────────────────────────────────────────────┘
```

---

## Tech Stack

| Layer | Technology | Notes |
|-------|-----------|-------|
| Orchestrator | HashiCorp Nomad (OSS) | Single binary, ~50-100MB RAM on clients |
| IaC | Terraform | OCI provider for control plane |
| Config Management | Ansible | Agentless, for node bootstrap and config |
| Mesh VPN | Netmaker (self-hosted) | WireGuard-based, zero per-device cost |
| Container Runtime | Docker | Already on all nodes |
| Monitoring | Prometheus + Grafana + Loki | On OCI ops-1 VM |
| Alerting | Alertmanager → Telegram | Via n8n webhook |
| Automation | n8n + Telegram Bot | Existing, on DigitalOcean |
| Remote Access | Cloudflare Tunnels + SSH | Existing infrastructure |
| VPN/Proxy | Outline VPN (SOCKS5) | Existing, for circumvention |

---

## Repository Structure

```
meridian-infra/
├── CLAUDE.md                         # This file
├── README.md                         # Project overview for humans
├── .gitignore
│
├── oci/                              # Terraform — OCI control plane
│   ├── main.tf                       # Provider, backend config
│   ├── network.tf                    # VCN, subnets, internet gateway, route tables
│   ├── security.tf                   # Security lists, NSGs
│   ├── compute.tf                    # ARM A1 + AMD Micro instances
│   ├── storage.tf                    # Block volumes, object storage
│   ├── variables.tf                  # Input variables
│   ├── outputs.tf                    # IPs, OCIDs for Ansible consumption
│   ├── terraform.tfvars              # Secrets (NEVER commit — in .gitignore)
│   ├── terraform.tfvars.example      # Template for tfvars
│   ├── backend.tf                    # OCI Object Storage S3-compat backend
│   └── cloud-init/
│       ├── nomad-server.yaml         # cloud-init: base packages, SSH hardening
│       ├── ops.yaml                  # cloud-init: Docker, base packages
│       └── bastion.yaml              # cloud-init: minimal, SSH only
│
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/
│   │   ├── hosts.yml                 # Static or generated from TF outputs
│   │   └── group_vars/
│   │       ├── nomad_servers.yml
│   │       ├── nomad_clients.yml
│   │       └── ops.yml
│   ├── playbooks/
│   │   ├── nomad-server.yml          # Install + configure Nomad server cluster
│   │   ├── nomad-client.yml          # Install + configure Nomad client on agents
│   │   ├── netmaker.yml              # Deploy Netmaker on ops-1
│   │   ├── monitoring.yml            # Prometheus + Grafana + Loki + Alertmanager
│   │   ├── bootstrap-agent.yml       # Full agent onboarding (Docker + Nomad + WG + exporter)
│   │   └── rotate-ip.yml            # IP rotation with drain + re-enroll
│   └── roles/
│       ├── common/                   # Base packages, SSH keys, sysctl tuning
│       ├── docker/                   # Docker CE installation
│       ├── nomad/                    # Nomad binary + config
│       ├── wireguard/                # WireGuard kernel module + Netmaker client
│       └── node-exporter/            # Prometheus node_exporter
│
├── nomad/
│   ├── jobs/
│   │   ├── app.nomad.hcl            # Main application (type: system)
│   │   ├── node-exporter.nomad.hcl  # Prometheus exporter (type: system)
│   │   └── monitoring.nomad.hcl     # Optional: run monitoring as Nomad jobs
│   └── policies/
│       └── n8n-token.hcl            # ACL policy for n8n API access (Phase 2)
│
├── monitoring/
│   ├── docker-compose.yml           # Prometheus + Grafana + Loki + Alertmanager
│   ├── prometheus/
│   │   ├── prometheus.yml            # Scrape configs (Nomad + node_exporter)
│   │   └── rules/
│   │       ├── nomad.yml             # Nomad-specific alert rules
│   │       └── node.yml              # Node-level alert rules
│   ├── grafana/
│   │   ├── provisioning/
│   │   │   ├── datasources.yml
│   │   │   └── dashboards.yml
│   │   └── dashboards/
│   │       ├── nomad-cluster.json
│   │       └── node-overview.json
│   ├── loki/
│   │   └── loki-config.yml
│   ├── promtail/
│   │   └── promtail-config.yml
│   └── alertmanager/
│       └── alertmanager.yml          # Telegram webhook via n8n
│
├── scripts/
│   ├── enroll-agent.sh               # One-liner: install Nomad + WG + join mesh
│   ├── rotate-ip.sh                  # Provider-agnostic IP rotation wrapper
│   ├── nomad-snapshot.sh             # Backup Nomad state
│   └── oci-arm-retry.sh              # Retry loop for ARM capacity issues
│
└── docs/
    ├── ops-runbook.md                # Day-to-day operations guide
    ├── network-topology.md           # WireGuard IPs, provider mapping
    ├── incident-response.md          # What to do when things break
    └── phase2-plan.md                # Plan for 40-node rollout
```

---

## Hard Constraints (Non-Negotiable)

1. **1 GB RAM VPS minimum spec** — Agent nodes have only 1 GB RAM. Every byte matters. Nomad client + Docker + WireGuard + node_exporter must leave ≥600 MB for the application container.

2. **No AWS/Azure/GCP** — Major cloud providers are excluded (except Alibaba and Tencent). Control plane is on OCI. Agents are on small IaaS providers.

3. **Public IP rotation on demand** — Any agent node's public IP must be rotatable via provider API. Nomad and WireGuard must survive IP changes without manual intervention.

4. **OCI Always Free limits** — Control plane must run within: 4 ARM OCPUs, 24 GB RAM, 200 GB boot volume, 200 GB block volume, 2 VCNs, 10 TB outbound/month. Going over means paying.

5. **Single engineer** — Win is the sole operator. Everything must be automated, documented, and recoverable by one person. Bus factor = 1, so documentation is critical.

6. **ARM64 architecture on OCI** — The Nomad servers and ops VM run on Ampere A1 (aarch64). All binaries, Docker images, and tools must support linux/arm64.

---

## OCI-Specific Knowledge

### Region
- **Home region:** `ap-singapore-1` (Singapore, Southeast Asia)
- **Region key:** `SIN`
- Always Free resources ONLY work in the home region
- Second Singapore region `ap-singapore-2` exists but free-tier availability unconfirmed

### Shapes
- **VM.Standard.A1.Flex** — ARM, configurable OCPUs/RAM (our: 1 OCPU, 6 GB × 4 VMs)
- **VM.Standard.E2.1.Micro** — AMD, burstable 1/8 OCPU, 1 GB (our: bastion + spare)

### Networking
- VCN CIDR: `10.0.0.0/16`
- Public subnet: `10.0.1.0/24` (Nomad servers, ops, bastion)
- Private subnet: `10.0.2.0/24` (reserved for future use)
- WireGuard mesh CIDR: `10.10.0.0/16` (Netmaker-managed)

### Terraform Provider
```hcl
terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = "ap-singapore-1"
}
```

### Terraform State Backend
Uses OCI Object Storage with S3-compatible API:
```hcl
backend "s3" {
  bucket                      = "meridian-tfstate"
  key                         = "oci/terraform.tfstate"
  region                      = "ap-singapore-1"
  endpoint                    = "https://<namespace>.compat.objectstorage.ap-singapore-1.oraclecloud.com"
  skip_region_validation      = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  force_path_style            = true
}
```

### Common OCI Pitfalls
- ARM A1 instances get "Out of host capacity" errors frequently on free-tier-only accounts. Upgrading to Pay-As-You-Go resolves this (no charge for Always Free resources).
- Boot volumes count toward Always Free storage (200 GB total). Default is ~47 GB per instance. 5 instances × 47 GB = 235 GB exceeds the limit. Use 40 GB boot volumes or accept ~$0.85/mo overage.
- Security lists have separate ingress/egress rules; both are required.
- OCI adds iptables rules on Oracle Linux by default. Ubuntu images are cleaner. Always use Ubuntu 24.04 for consistency.
- `assign_public_ip = true` requires a public subnet with an internet gateway and route table.

---

## Nomad-Specific Knowledge

### Cluster Topology
- **3 server nodes** — Raft consensus, tolerates 1 node failure
- **N client nodes** — Agents that run workloads
- **Region:** `global` (single region)
- **Datacenters:** One per provider — `dc-alicloud`, `dc-tencent`, `dc-vultr`, `dc-hetzner`, `dc-contabo`, etc.

### Key Ports
| Port | Protocol | Purpose |
|------|----------|---------|
| 4646 | TCP | HTTP API |
| 4647 | TCP | RPC (internal) |
| 4648 | TCP+UDP | Serf gossip |

### Server Config Template
```hcl
# /etc/nomad.d/nomad.hcl (server)
datacenter = "dc-oci"
data_dir   = "/opt/nomad/data"
bind_addr  = "0.0.0.0"

advertise {
  http = "{{ wireguard_ip }}:4646"
  rpc  = "{{ wireguard_ip }}:4647"
  serf = "{{ wireguard_ip }}:4648"
}

server {
  enabled          = true
  bootstrap_expect = 3
  encrypt          = "{{ gossip_key }}"  # nomad operator gossip keyring generate
}

telemetry {
  collection_interval        = "10s"
  disable_hostname           = true
  prometheus_metrics         = true
  publish_allocation_metrics = true
  publish_node_metrics       = true
}
```

### Client Config Template
```hcl
# /etc/nomad.d/nomad.hcl (client)
datacenter = "{{ datacenter }}"  # e.g., dc-alicloud
data_dir   = "/opt/nomad/data"
bind_addr  = "0.0.0.0"

advertise {
  http = "{{ wireguard_ip }}:4646"
  rpc  = "{{ wireguard_ip }}:4647"
  serf = "{{ wireguard_ip }}:4648"
}

client {
  enabled = true
  servers = [
    "{{ nomad_server_1_wg_ip }}:4647",
    "{{ nomad_server_2_wg_ip }}:4647",
    "{{ nomad_server_3_wg_ip }}:4647",
  ]

  meta {
    provider = "{{ provider_name }}"
    region   = "{{ geo_region }}"
  }

  host_network "public" {
    cidr           = "{{ public_ip }}/32"
    reserved_ports = "22"
  }
}

plugin "docker" {
  config {
    allow_privileged = false
    volumes {
      enabled = true
    }
  }
}
```

### Job Types Used
- **`system`** — Runs on every matching client. Used for: main application, node_exporter.
- **`service`** — Long-running with scheduling. Used for: monitoring stack (if run as Nomad jobs).
- **`batch`** — One-off tasks. Used for: maintenance scripts, backups.

### Nomad API Endpoints (for n8n integration)
| Operation | Method | Endpoint |
|-----------|--------|----------|
| Submit/update job | PUT | `/v1/jobs` |
| Job status | GET | `/v1/job/{id}` |
| Job summary | GET | `/v1/job/{id}/summary` |
| List allocations | GET | `/v1/job/{id}/allocations` |
| Node status | GET | `/v1/nodes` |
| Drain node | POST | `/v1/node/{id}/drain` |
| Force GC | PUT | `/v1/system/gc` |

---

## Networking

### WireGuard Mesh (Netmaker)
- **Server:** Netmaker on `ops-1` (OCI)
- **Network name:** `meridian-mesh`
- **CIDR:** `10.10.0.0/16`
- **Port:** `51820/UDP`
- All Nomad traffic (API, RPC, Serf) flows over WireGuard IPs
- Agent enrollment: `netclient join -t <enrollment_token>`

### IP Rotation Flow
```
1. [Telegram Bot] → "rotate ip agent-47"
2. [n8n workflow] →
   a. POST /v1/node/{id}/drain (Nomad — graceful drain)
   b. Wait for drain complete
   c. Call provider API to rotate public IP
   d. Wait for WireGuard tunnel to re-establish (Netmaker auto-detects)
   e. POST /v1/node/{id}/drain with enable=false (re-enable)
   f. Verify allocation is running
   g. Reply to Telegram with new IP
```

### Security Posture
- Nomad API, RPC, Serf: ONLY accessible over WireGuard (10.10.0.0/16)
- SSH: Only via bastion or Cloudflare Tunnel (no direct SSH to Nomad servers)
- WireGuard port (51820/UDP): Open to 0.0.0.0/0 (required for NAT traversal)
- Grafana/Prometheus: Only over WireGuard
- Nomad gossip encryption: Enabled (symmetric key)
- Nomad mTLS: Phase 2 (not in Phase 1 scope)
- Nomad ACLs: Phase 2

---

## Monitoring

### Prometheus Scrape Targets
```yaml
scrape_configs:
  - job_name: 'nomad-servers'
    metrics_path: '/v1/metrics'
    params:
      format: ['prometheus']
    static_configs:
      - targets:
        - '10.10.0.1:4646'   # nomad-server-1
        - '10.10.0.2:4646'   # nomad-server-2
        - '10.10.0.3:4646'   # nomad-server-3

  - job_name: 'node-exporter'
    # Dynamically discovered via Nomad service registration
    # or static list maintained in Ansible
    static_configs:
      - targets: ['10.10.1.1:9100', '10.10.1.2:9100', ...]
```

### Alert Rules (Critical)
- `NomadNodeDown` — Client node not reporting for > 3 minutes
- `NomadJobFailed` — Allocation in failed state for > 2 minutes
- `NomadServerLost` — Fewer than 3 server peers for > 1 minute
- `NodeHighMemory` — Memory usage > 85% on any agent (critical on 1 GB VPS)
- `NodeHighCPU` — CPU usage > 90% sustained for > 5 minutes
- `NodeDiskFull` — Disk usage > 90%
- `WireGuardPeerDown` — WireGuard handshake age > 5 minutes

### Alertmanager → Telegram
```yaml
# alertmanager.yml
route:
  receiver: 'telegram-n8n'
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h

receivers:
  - name: 'telegram-n8n'
    webhook_configs:
      - url: 'https://your-n8n-instance.com/webhook/meridian-alerts'
        send_resolved: true
```

---

## Coding Conventions

### Terraform
- Use `snake_case` for all resource names and variables
- Prefix OCI resources with purpose: `nomad_server_`, `ops_`, `bastion_`
- Always tag resources: `freeform_tags = { project = "meridian", phase = "1", role = "nomad-server" }`
- Use `templatefile()` for cloud-init, never inline
- Keep `.tfvars` out of git; provide `.tfvars.example`
- Use `locals` for computed values (CIDR calculations, naming)
- Pin provider versions

### Ansible
- Use YAML format for all playbooks and inventory
- Role-based structure, even for simple tasks
- Variables in `group_vars/`, never hardcoded in playbooks
- Use `ansible-vault` for secrets (Netmaker tokens, Nomad gossip key)
- Idempotent: every playbook must be safe to re-run
- Tag all tasks for selective execution: `--tags nomad`, `--tags wireguard`

### Nomad Job Specs
- Use `.nomad.hcl` extension (HCL2 format)
- One file per job
- Always set explicit `resources { cpu = ... memory = ... }` — never rely on defaults
- Always include `service` block with health check
- Use `meta` for provider/region tagging
- Pin Docker image tags, never use `:latest` in production

### Shell Scripts
- `#!/usr/bin/env bash` with `set -euo pipefail`
- Use functions for logical grouping
- Log to stdout with timestamps
- Exit codes: 0 = success, 1 = error, 2 = dependency missing

### Documentation
- All docs in Markdown
- Ops runbook follows: Symptom → Diagnosis → Resolution format
- Architecture diagrams in ASCII (for portability) or Mermaid

---

## File Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Terraform | `<purpose>.tf` | `compute.tf`, `network.tf` |
| Ansible playbook | `<action>.yml` | `bootstrap-agent.yml` |
| Ansible role | `<tool>/` | `roles/nomad/`, `roles/docker/` |
| Nomad job | `<name>.nomad.hcl` | `app.nomad.hcl` |
| Shell script | `<verb>-<noun>.sh` | `rotate-ip.sh`, `enroll-agent.sh` |
| Documentation | `<topic>.md` | `ops-runbook.md` |

---

## Phase 1 Status Tracker

### Week 1: Infrastructure Provisioning
- [ ] OCI account created with `ap-singapore-1` home region
- [ ] Upgraded to Pay-As-You-Go
- [ ] OCI API keys generated and configured
- [ ] Terraform project initialized with OCI provider
- [ ] Object Storage bucket created for TF state
- [ ] VCN + subnets + security lists applied
- [ ] 3x ARM A1 Nomad server VMs provisioned
- [ ] 1x ARM A1 ops VM provisioned
- [ ] 1x AMD Micro bastion VM provisioned
- [ ] SSH access verified through bastion
- [ ] Nomad installed on all 3 server VMs (ARM64 binary)
- [ ] Nomad cluster formed: `nomad server members` shows 3 nodes
- [ ] Netmaker deployed on ops-1 (Docker Compose)
- [ ] WireGuard mesh created: `meridian-mesh`
- [ ] All OCI VMs enrolled in mesh and can ping each other
- [ ] Nomad servers reconfigured to advertise on WireGuard IPs

### Week 2: Application & Validation
- [ ] 3 pilot agent VPS selected (different providers)
- [ ] Ansible `bootstrap-agent.yml` playbook written and tested
- [ ] 3 pilot agents enrolled in Nomad cluster
- [ ] `app.nomad.hcl` job spec written
- [ ] Application deployed across 3 pilot agents
- [ ] Health checks passing
- [ ] Rolling update tested
- [ ] Prometheus + Grafana deployed on ops-1
- [ ] Metrics visible from all nodes in Grafana
- [ ] Alertmanager → Telegram pipeline verified
- [ ] IP rotation tested on 1 pilot agent (full cycle)
- [ ] Server failure test: kill 1 server, verify cluster survives
- [ ] Ops runbook first draft complete
- [ ] Phase 1 deliverables checklist complete

---

## Useful Commands

### Terraform
```bash
cd oci/
terraform init                          # Initialize
terraform plan -out=tfplan              # Preview changes
terraform apply tfplan                  # Apply
terraform output -json > ../ansible/inventory/tf_outputs.json  # Export for Ansible
terraform destroy                       # Tear down (careful!)
```

### Nomad
```bash
export NOMAD_ADDR="http://10.10.0.1:4646"   # WireGuard IP of leader

nomad server members                    # Check server cluster health
nomad node status                       # List all client nodes
nomad job run nomad/jobs/app.nomad.hcl  # Deploy job
nomad job status app                    # Check job status
nomad alloc status <alloc-id>           # Check specific allocation
nomad alloc logs <alloc-id>             # View container logs
nomad node drain -enable <node-id>      # Drain before IP rotation
nomad node drain -disable <node-id>     # Re-enable after IP rotation
nomad operator snapshot save backup.snap # Backup cluster state
nomad operator snapshot restore backup.snap
```

### Ansible
```bash
cd ansible/

# Bootstrap OCI Nomad servers
ansible-playbook playbooks/nomad-server.yml -i inventory/hosts.yml

# Enroll a new agent
ansible-playbook playbooks/bootstrap-agent.yml -i inventory/hosts.yml --limit new_agent

# Deploy monitoring stack
ansible-playbook playbooks/monitoring.yml -i inventory/hosts.yml

# Run specific role only
ansible-playbook playbooks/bootstrap-agent.yml --tags wireguard
```

### Netmaker
```bash
# On ops-1
cd /opt/netmaker && docker compose up -d    # Start Netmaker
docker compose logs -f                       # Check logs

# On any node
netclient join -t <enrollment_token>         # Join mesh
netclient list                               # Show networks
wg show                                      # WireGuard status
```

### Monitoring
```bash
# On ops-1
cd /opt/monitoring && docker compose up -d

# Check Prometheus targets
curl -s http://10.10.0.10:9090/api/v1/targets | jq '.data.activeTargets[] | {instance: .labels.instance, health: .health}'

# Grafana: http://10.10.0.10:3000 (admin/admin on first login, CHANGE IMMEDIATELY)
```

---

## Environment Variables

```bash
# OCI Terraform (set in shell or .envrc)
export TF_VAR_tenancy_ocid="ocid1.tenancy.oc1..<unique>"
export TF_VAR_user_ocid="ocid1.user.oc1..<unique>"
export TF_VAR_fingerprint="<api_key_fingerprint>"
export TF_VAR_private_key_path="~/.oci/oci.pem"
export TF_VAR_compartment_id="ocid1.compartment.oc1..<unique>"
export TF_VAR_ssh_public_key="$(cat ~/.ssh/meridian.pub)"

# Nomad CLI
export NOMAD_ADDR="http://10.10.0.1:4646"
# export NOMAD_TOKEN="<acl_token>"  # Phase 2

# Ansible
export ANSIBLE_CONFIG="./ansible/ansible.cfg"
```

---

## Secrets Management (Phase 1)

| Secret | Storage | Notes |
|--------|---------|-------|
| OCI API private key | `~/.oci/oci.pem` (local) | Never commit |
| SSH key pair | `~/.ssh/meridian` + `.pub` | Used for all OCI + agent VMs |
| Nomad gossip key | `ansible-vault` encrypted | Generated via `nomad operator gossip keyring generate` |
| Netmaker enrollment token | `ansible-vault` encrypted | Generated in Netmaker UI/API |
| Grafana admin password | `ansible-vault` encrypted | Change from default on first login |
| Terraform tfvars | `oci/terraform.tfvars` (gitignored) | Contains all OCI OCIDs |

**Phase 2 additions:** Nomad ACL bootstrap token, mTLS CA certs, n8n API tokens.

---

## Known Issues & Workarounds

| Issue | Workaround |
|-------|-----------|
| OCI ARM "Out of host capacity" | Upgrade to PAYG; use retry script (`scripts/oci-arm-retry.sh`) that polls every 60s |
| OCI boot volume 200 GB limit shared | Use 40 GB boot volumes (5 × 40 = 200 GB exactly) |
| Nomad on ARM64 — ensure correct binary | Download `nomad_<version>_linux_arm64.zip` from releases.hashicorp.com |
| Docker images must support ARM64 | Use multi-arch images or build with `--platform linux/arm64` |
| WireGuard port may be blocked by some VPS providers | Use Netmaker relay mode through a node with open UDP; or fallback to Cloudflare Tunnel |
| Netmaker endpoint stale after IP rotation | Netmaker client auto-detects via STUN; if not, run `netclient pull` on the rotated node |
| Prometheus scrape fails after agent IP rotation | Scrape targets use WireGuard IPs (stable), not public IPs |

---

## What NOT to Do

- **Don't use `:latest` Docker tags** in Nomad job specs — pin versions for reproducibility
- **Don't expose Nomad API to the internet** — always behind WireGuard
- **Don't hardcode IPs in Nomad configs** — use WireGuard IPs managed by Netmaker
- **Don't run Terraform without a state backend** — always use the OCI Object Storage backend
- **Don't skip health checks** in Nomad jobs — they are the only way Nomad knows if your app is alive
- **Don't commit secrets** — use `.gitignore` and `ansible-vault`
- **Don't allocate more than 512 MB memory** to app containers on 1 GB VPS nodes — leave room for system + Nomad + Docker + WireGuard
- **Don't use `WidthType.PERCENTAGE`** in OCI Terraform (wrong context, but a reminder from our doc generation)
- **Don't create instances in a region other than `ap-singapore-1`** — Always Free only works in home region

---

## Integration Points (Existing Infrastructure)

| System | How It Connects to Meridian |
|--------|---------------------------|
| n8n (DigitalOcean) | Calls Nomad HTTP API over WireGuard for job management, IP rotation workflows |
| Telegram Bot | Triggers n8n workflows; receives Alertmanager notifications |
| Cloudflare Tunnels | Existing remote access; may be used as WireGuard fallback |
| Alibaba Cloud API | Provider API for IP rotation on existing 40 nodes |
| Provider APIs (various) | Each VPS provider has its own API for IP rotation |

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| Mar 2026 | Nomad over Kubernetes | 50-100 MB RAM vs 500-700 MB on 1 GB VPS nodes; native multi-DC |
| Mar 2026 | OCI Always Free for control plane | $0/month, 4 OCPU + 24 GB ARM, 10 TB egress, Singapore region |
| Mar 2026 | Netmaker over Tailscale | No per-device cost at 300 nodes; self-hosted; WireGuard-native |
| Mar 2026 | Prometheus+Grafana+Loki over Zabbix | Best Nomad integration; Telegram alerting; lighter on resources |
| Mar 2026 | Ansible over Salt/Puppet | Agentless (no RAM overhead on 1 GB nodes); works across all providers |
| Mar 2026 | 3 Nomad servers (not 5) | 3 fits OCI free tier; tolerates 1 failure; 5 is overkill for <300 nodes |
| Mar 2026 | Ubuntu 24.04 over Oracle Linux | Cleaner iptables defaults; wider community support; Win's familiarity |
| Mar 2026 | Terraform for OCI only | Agent VPS are provisioned via provider APIs/UI; Terraform manages OCI control plane |

---

## Glossary

| Term | Meaning |
|------|---------|
| Agent / Client | A VPS running Nomad client + Docker + the application |
| Control Plane | The 3 Nomad server nodes + ops VM on OCI |
| Datacenter (Nomad) | Logical grouping by provider: `dc-alicloud`, `dc-vultr`, etc. |
| Drain | Gracefully remove workloads from a node before maintenance/IP rotation |
| Enrollment | Process of adding a new VPS to the Nomad cluster + WireGuard mesh |
| IP Rotation | Replacing a VPS's public IP via provider API (circumvention requirement) |
| Mesh | The WireGuard overlay network connecting all nodes (Netmaker-managed) |
| System Job | Nomad job type that runs one instance on every matching client node |
| ops-1 | The OCI VM running Netmaker, Prometheus, Grafana, Loki, Alertmanager |
