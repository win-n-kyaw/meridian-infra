# Progress-1: Phase 1 — Foundation & Control Plane

**Date started:** 2026-03-05
**Last updated:** 2026-03-06
**Status:** In Progress

---

## Deviations from CLAUDE.md

| Aspect | Original Plan (OCI) | Current Reality (AWS) | Impact |
|--------|---------------------|----------------------|--------|
| Cloud provider | OCI Always Free (ap-singapore-1) | AWS ap-southeast-1 (temporary) | Costs money — destroy when done |
| Instance types | A1.Flex (1C/6GB) + E2.Micro | t4g.large (ARM) + t3.micro (bastion) | Same ARM64 arch, compatible |
| State backend | OCI Object Storage (S3-compat) | Local state (S3 backend commented out) | OK for testing, not for prod |
| Terraform dir | `oci/` | `aws/` | Separate directory, original OCI intact |
| SSH key issue | N/A | Instances recreated — key now matches | Resolved (see learning-1.md) |
| SG fix needed | OCI security lists | Added VPC CIDR SSH ingress for ProxyJump | Applied to `instance_base` SG |

---

## Infrastructure State

```
Bastion:        13.215.194.239 (public) — SSH jump host only
Nomad Server 1: 10.0.1.212    (private, via bastion)
Nomad Server 2: 10.0.1.144    (private, via bastion)
Nomad Server 3: 10.0.1.205    (private, via bastion)
Ops-1:          10.0.1.131    (private, via bastion) — recreated 2026-03-06
```

SSH access: Verified on all 5 hosts.

---

## The Plan — Lego Blocks

Each block is a small, testable unit. Complete one, verify it works, then build the next on top. Every block has a **verify** step — don't move on until it passes.

### Block 1: SSH Access
**Status: DONE**

- [x] Terraform apply → 5 instances running
- [x] SSH config with `IdentitiesOnly yes`
- [x] VPC CIDR SSH ingress rule for ProxyJump

**Verify:**
```bash
ssh bastion-meridian 'echo OK'
ssh nomad-server-1 'echo OK'
ssh nomad-server-2 'echo OK'
ssh nomad-server-3 'echo OK'
ssh ops-1 'echo OK'
```

---

### Block 2: Install Nomad Binary (3 Servers)
**Status: DONE**

Install the Nomad ARM64 binary on all 3 server nodes.

**Steps (run on each nomad-server via SSH):**
```bash
# 1. Check latest version at https://releases.hashicorp.com/nomad/
NOMAD_VERSION="1.9.7"  # verify latest stable

# 2. Download and install
curl -fsSL "https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_arm64.zip" -o /tmp/nomad.zip
sudo unzip -o /tmp/nomad.zip -d /usr/local/bin/
rm /tmp/nomad.zip

# 3. Verify
nomad version
```

**Verify:**
```bash
ssh nomad-server-1 'nomad version'
ssh nomad-server-2 'nomad version'
ssh nomad-server-3 'nomad version'
```

---

### Block 3: Configure Nomad Servers (Using VPC IPs)
**Status: DONE**

Write Nomad server config and systemd unit. Use **VPC private IPs** for now (WireGuard comes later).

**Steps (on each nomad-server):**

1. Generate gossip encryption key (once, on any server):
```bash
nomad operator gossip keyring generate
# Save this key — same key goes on all servers
```

2. Write config `/etc/nomad.d/nomad.hcl` (adjust PRIVATE_IP per server):
```hcl
datacenter = "dc-aws"
data_dir   = "/opt/nomad/data"
bind_addr  = "0.0.0.0"

advertise {
  http = "PRIVATE_IP:4646"
  rpc  = "PRIVATE_IP:4647"
  serf = "PRIVATE_IP:4648"
}

server {
  enabled          = true
  bootstrap_expect = 3
  encrypt          = "gossip_key"
}

telemetry {
  collection_interval        = "10s"
  disable_hostname           = true
  prometheus_metrics         = true
  publish_allocation_metrics = true
  publish_node_metrics       = true
}
```

Private IPs for each server:
- nomad-server-1: `10.0.1.212`
- nomad-server-2: `10.0.1.144`
- nomad-server-3: `10.0.1.205`

3. Write systemd unit `/etc/systemd/system/nomad.service`:
```ini
[Unit]
Description=Nomad
Documentation=https://www.nomadproject.io/docs/
Wants=network-online.target
After=network-online.target

[Service]
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/local/bin/nomad agent -config /etc/nomad.d
KillMode=process
KillSignal=SIGINT
LimitNOFILE=65536
LimitNPROC=infinity
Restart=on-failure
RestartSec=2
TasksMax=infinity
OOMScoreAdjust=-1000

[Install]
WantedBy=multi-user.target
```

4. Start Nomad:
```bash
sudo systemctl daemon-reload
sudo systemctl enable nomad
sudo systemctl start nomad
```

**Verify:**
```bash
# On any nomad-server:
nomad server members
# Expected: 3 members, all "alive"
```

---

### Block 4: Verify Nomad Cluster Health
**Status: DONE**

```bash
# From any nomad-server:
nomad server members          # 3 alive members
nomad status                  # no jobs yet, but API works
nomad operator raft list-peers  # 3 voters, 1 leader

# From your local machine (via SSH tunnel):
ssh -L 4646:10.0.1.212:4646 bastion-meridian -N &
export NOMAD_ADDR="http://127.0.0.1:4646"
nomad server members           # works from local if Nomad CLI installed
```

**Verify:** All 3 servers are `alive`, one is `leader`.

---

### Block 5: Docker + Monitoring on ops-1
**Status: PARTIAL** — Grafana running, Prometheus skipped (permissions issue on EBS bind mount)

Deploy Prometheus + Grafana on ops-1 to scrape Nomad servers.

**What's done:**
- Docker verified on ops-1
- EBS volume formatted and mounted at `/mnt/prometheus-data`
- `docker-compose.yml` and `prometheus.yml` deployed to `/opt/monitoring/`
- Grafana running on port 3000

**Remaining:**
- Fix Prometheus: `sudo chown -R 65534:65534 /mnt/prometheus-data` (Prometheus runs as UID 65534/nobody)
- Then: `cd /opt/monitoring && sudo docker compose up -d prometheus`

**Verify:**
```bash
# SSH tunnel to check Prometheus targets
ssh -L 9090:10.0.1.97:9090 bastion-meridian -N &
curl -s http://127.0.0.1:9090/api/v1/targets | jq '.data.activeTargets[] | {instance, health}'

# SSH tunnel to check Grafana
ssh -L 3000:10.0.1.97:3000 bastion-meridian -N &
# Open http://127.0.0.1:3000 in browser
```

---

### Block 6: Netmaker (WireGuard Mesh) on ops-1
**Status: TODO**

Deploy Netmaker on ops-1, create the WireGuard mesh, enroll all 5 AWS nodes. This is the **critical path** — without it, external agents (Alibaba etc.) cannot join the Nomad cluster.

#### Prerequisites
- ops-1 has Docker running (verified in Block 5)
- Security group `ops` must allow UDP 51820 (WireGuard) — check `aws/security.tf`
- All nodes need outbound UDP 51820 allowed

#### Step 6.1: Open WireGuard port in security groups

Check if UDP 51820 is already open. If not, add to `aws/security.tf`:
```hcl
# In the "ops" security group:
ingress {
  description = "WireGuard"
  from_port   = 51820
  to_port     = 51820
  protocol    = "udp"
  cidr_blocks = ["0.0.0.0/0"]  # required for NAT traversal
}

# In the "instance_base" security group (for Nomad servers + bastion):
ingress {
  description = "WireGuard"
  from_port   = 51820
  to_port     = 51820
  protocol    = "udp"
  cidr_blocks = ["0.0.0.0/0"]
}
```
Then `terraform apply`.

**Verify:**
```bash
aws ec2 describe-security-groups --profile meridian-lead --region ap-southeast-1 \
  --filters "Name=group-name,Values=meridian-ops" \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`51820`]'
```

#### Step 6.2: Deploy Netmaker on ops-1

Netmaker v0.24+ uses a single Docker Compose file. Deploy on ops-1:

```bash
ssh ops-1

# Create directory
sudo mkdir -p /opt/netmaker && cd /opt/netmaker

# Download the official docker-compose (check latest at https://github.com/gravitl/netmaker)
# For a quick setup, use Netmaker's nm-quick script:
sudo curl -fsSL https://raw.githubusercontent.com/gravitl/netmaker/master/scripts/nm-quick.sh -o nm-quick.sh
sudo chmod +x nm-quick.sh

# Run the quick install (community edition)
# It will ask for a domain — for testing, use the ops-1 public IP or a subdomain
# Since ops-1 has no public domain, use IP-based setup
sudo ./nm-quick.sh
```

**Alternative (manual Docker Compose):** If nm-quick doesn't suit the environment, we can write a custom `docker-compose.yml`. The quick script is the fastest path for testing.

**Verify:**
```bash
ssh ops-1 'sudo docker ps | grep netmaker'
# Should see: netmaker, netmaker-ui, coredns, mosquitto (MQTT broker)
```

#### Step 6.3: Create the mesh network

Access the Netmaker dashboard:
```bash
# SSH tunnel to Netmaker UI (default port 8443 or 443 depending on setup)
ssh -L 8443:10.0.1.97:8443 bastion-meridian -N &
# Open https://127.0.0.1:8443 in browser
```

In the dashboard:
1. Log in with the admin credentials from nm-quick output
2. Create a new network: **Name:** `meridian-mesh`, **CIDR:** `10.10.0.0/16`
3. Generate an **enrollment key** (save it — needed for all nodes)

**Alternative (CLI):**
```bash
ssh ops-1
# Use nmctl (Netmaker CLI) if installed:
nmctl network create --name meridian-mesh --ipv4_addr 10.10.0.0/16
nmctl enrollment_key create --networks meridian-mesh --unlimited
# Save the token output
```

#### Step 6.4: Enroll ops-1 (first node)

```bash
ssh ops-1

# Install netclient
curl -fsSL https://apt.netmaker.org/gpg.key | sudo tee /etc/apt/trusted.gpg.d/netclient.asc
echo "deb https://apt.netmaker.org stable main" | sudo tee /etc/apt/sources.list.d/netclient.list
sudo apt update && sudo apt install -y netclient

# Join the mesh
sudo netclient join -t <ENROLLMENT_TOKEN>
```

**Verify:**
```bash
ssh ops-1 'sudo wg show'
# Should show a WireGuard interface (nm-meridian-mesh or similar)
# Note the assigned IP (should be 10.10.0.X)
```

#### Step 6.5: Enroll Nomad servers (3 nodes)

Repeat on each nomad-server:
```bash
# For each server (nomad-server-1, nomad-server-2, nomad-server-3):
ssh nomad-server-X

# Install netclient (same commands as ops-1)
curl -fsSL https://apt.netmaker.org/gpg.key | sudo tee /etc/apt/trusted.gpg.d/netclient.asc
echo "deb https://apt.netmaker.org stable main" | sudo tee /etc/apt/sources.list.d/netclient.list
sudo apt update && sudo apt install -y netclient

sudo netclient join -t <ENROLLMENT_TOKEN>
```

**Verify after all 3:**
```bash
for h in nomad-server-1 nomad-server-2 nomad-server-3; do
  echo "=== $h ==="
  ssh $h 'sudo wg show | head -5'
done
```

#### Step 6.6: Enroll bastion (optional)

The bastion doesn't run Nomad, but enrolling it in the mesh gives you direct WireGuard access to all nodes from the bastion. This is optional for Phase 1 testing.

#### Step 6.7: Cross-node ping test

```bash
# From ops-1, ping all Nomad servers on WireGuard IPs
ssh ops-1 'ping -c 2 10.10.0.X && ping -c 2 10.10.0.Y && ping -c 2 10.10.0.Z'

# From nomad-server-1, ping the others
ssh nomad-server-1 'ping -c 2 10.10.0.Y && ping -c 2 10.10.0.Z && ping -c 2 10.10.0.W'
```

**Record the WireGuard IPs** — you'll need them for Block 7:
```
ops-1:           10.10.0.?
nomad-server-1:  10.10.0.?
nomad-server-2:  10.10.0.?
nomad-server-3:  10.10.0.?
```

**Block 6 DONE when:** All 4 nodes (3 servers + ops-1) show `wg show` with active peers and can ping each other on 10.10.0.X IPs.

---

### Block 7: Reconfigure Nomad to WireGuard IPs
**Status: TODO — After Block 6**

Update `advertise` blocks on all 3 Nomad servers to use WireGuard IPs instead of VPC IPs. This is the **target architecture** — all Nomad traffic flows over the mesh, making the cluster provider-agnostic.

#### Prerequisites
- Block 6 complete — all 3 Nomad servers enrolled in WireGuard mesh
- You have the WireGuard IPs recorded from Block 6 Step 6.7

#### Step 7.1: Record the IP mapping

Fill in from Block 6 output:
```
nomad-server-1:  VPC 10.0.1.212 → WG 10.10.0.?
nomad-server-2:  VPC 10.0.1.144 → WG 10.10.0.?
nomad-server-3:  VPC 10.0.1.205 → WG 10.10.0.?
```

#### Step 7.2: Update Nomad config on each server

On **each** nomad-server, edit `/etc/nomad.d/nomad.hcl` — change only the `advertise` block and add `retry_join`:

```hcl
advertise {
  http = "WG_IP:4646"
  rpc  = "WG_IP:4647"
  serf = "WG_IP:4648"
}

server {
  enabled          = true
  bootstrap_expect = 3
  encrypt          = "EXISTING_GOSSIP_KEY"

  # Add retry_join with WireGuard IPs of all servers
  server_join {
    retry_join = ["WG_IP_SERVER1:4648", "WG_IP_SERVER2:4648", "WG_IP_SERVER3:4648"]
  }
}
```

Replace `WG_IP` with the actual WireGuard IP for that specific server.

#### Step 7.3: Rolling restart (one at a time)

**Important:** Do NOT restart all 3 at once — rolling restart preserves quorum.

```bash
# 1. Restart server-3 first (non-leader)
ssh nomad-server-3 'sudo systemctl restart nomad'
sleep 10
ssh nomad-server-1 'nomad server members'
# Expect: server-3 now advertising WG IP, others still on VPC IP
# Cluster should still have 3 alive members

# 2. Restart server-2
ssh nomad-server-2 'sudo systemctl restart nomad'
sleep 10
ssh nomad-server-1 'nomad server members'
# Expect: server-2 and server-3 on WG IPs

# 3. Restart server-1 (leader last)
ssh nomad-server-1 'sudo systemctl restart nomad'
sleep 15  # leader election takes a moment
ssh nomad-server-1 'nomad server members'
# Expect: all 3 on WG IPs, new leader elected
```

#### Step 7.4: Verify cluster health on new IPs

```bash
# From any server:
ssh nomad-server-1 'nomad server members'
# All 3 should show WireGuard IPs (10.10.0.X) in the Address column

ssh nomad-server-1 'nomad operator raft list-peers'
# 3 voters, 1 leader, all on WG IPs

ssh nomad-server-1 'nomad status'
# API responds (no jobs yet, that's fine)
```

#### Step 7.5: Update Prometheus scrape targets (if Prometheus is running)

Update `/opt/monitoring/prometheus/prometheus.yml` on ops-1 to use WireGuard IPs:
```yaml
static_configs:
  - targets:
      - "WG_IP_SERVER1:4646"
      - "WG_IP_SERVER2:4646"
      - "WG_IP_SERVER3:4646"
```
Then: `ssh ops-1 'cd /opt/monitoring && sudo docker compose restart prometheus'`

#### Rollback plan

If the cluster doesn't reform after all 3 restarts:
1. Revert `/etc/nomad.d/nomad.hcl` on all 3 servers back to VPC IPs
2. Stop Nomad on all 3: `sudo systemctl stop nomad`
3. Start all 3: `sudo systemctl start nomad`
4. Cluster will reform on VPC IPs
5. Debug WireGuard connectivity before retrying

**Block 7 DONE when:** `nomad server members` shows all 3 servers alive, advertising WireGuard IPs (10.10.0.X).

---

### Block 8: End-to-End Validation
**Status: TODO — Final**

- [ ] Nomad cluster: 3 servers alive on WireGuard IPs
- [ ] Prometheus: scraping all 3 Nomad servers, targets healthy
- [ ] Grafana: dashboard visible with metrics
- [ ] WireGuard mesh: all 5 nodes can ping each other
- [ ] SSH: all access works via bastion
- [ ] Kill 1 Nomad server → cluster survives → restart → rejoins

---

## Session Log

| Date | What was done | Blocks completed |
|------|---------------|-----------------|
| 2026-03-05 | Terraform apply, SSH debugging (key mismatch, SG fix), all 5 hosts accessible | Block 1 |
| 2026-03-06 | Instances recreated, SSH re-verified, Nomad cluster bootstrapped (Blocks 2-4), Grafana on ops-1 (Block 5 partial), Prometheus skipped | Blocks 1-4 DONE, Block 5 partial |
| 2026-03-06 | SG fix (targeted destroy/recreate ops-1, new IP .131), Netmaker failed (needs domain+TLS), pivoted to plain WireGuard. See **Progress-2.md** | Block 6 replanned |

---

## Notes

- **AWS costs money** — destroy with `terraform destroy` when testing is done
- **VPC IPs are temporary** — the real target is WireGuard IPs for all inter-node communication
- Blocks 5 and 6 can run in parallel since they're independent services on ops-1
- Block 7 depends on Block 6 (need WireGuard IPs first)
- No Ansible playbooks yet — manual setup is fine for 5 nodes during testing. Ansible comes in Phase 2 for the 40-node fleet rollout
