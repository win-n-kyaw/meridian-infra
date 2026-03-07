# Progress-2: Phase 1 — WireGuard Mesh & Nomad Migration

**Date started:** 2026-03-06
**Continues from:** Progress-1.md
**Status:** Planning

---

## Context

Netmaker's nm-quick.sh failed on ops-1 because it requires a public domain with TLS certificates (Caddy ACME challenge). ops-1 is on a private subnet behind a bastion — no domain, no public ports 80/443.

**Decision:** Use **plain WireGuard with static configs** for Phase 1 testing (4 nodes on AWS). Swap to Netmaker later when on OCI with a proper domain.

---

## Revised Plan — Blocks 6-8

### Block 6 (Revised): Plain WireGuard Mesh

**Status: TODO**

Replace Netmaker with manual WireGuard peer-to-peer configs. For 4 nodes, this is simpler and more reliable.

#### Architecture

```
           WireGuard Mesh (10.10.0.0/24)
    ┌──────────┬──────────┬──────────┐
    │          │          │          │
 ops-1    server-1   server-2   server-3
10.10.0.1  10.10.0.2  10.10.0.3  10.10.0.4
    │          │          │          │
  (VPC)      (VPC)      (VPC)      (VPC)
10.0.1.131 10.0.1.212 10.0.1.144 10.0.1.205
```

All nodes are in the same VPC, so WireGuard peers use **VPC private IPs** as endpoints (no NAT traversal needed). UDP 51820 is already open in both `ops` and `instance_base` SGs.

#### Step 6.1: Install WireGuard on all 4 nodes

```bash
# Run on each node (ops-1, nomad-server-1, nomad-server-2, nomad-server-3):
sudo apt update && sudo apt install -y wireguard
```

**Verify:**
```bash
for h in ops-1 nomad-server-1 nomad-server-2 nomad-server-3; do
  echo "=== $h ==="
  ssh $h 'which wg && echo OK'
done
```

#### Step 6.2: Generate keypairs on each node

```bash
# On each node:
wg genkey | sudo tee /etc/wireguard/private.key
sudo chmod 600 /etc/wireguard/private.key
sudo cat /etc/wireguard/private.key | wg pubkey | sudo tee /etc/wireguard/public.key
```

**Collect all public keys** — you need them for the config files:
```bash
for h in ops-1 nomad-server-1 nomad-server-2 nomad-server-3; do
  echo "$h: $(ssh $h 'sudo cat /etc/wireguard/public.key')"
done
```

Record them:
```
ops-1:           <PUB_KEY_OPS>
nomad-server-1:  <PUB_KEY_S1>
nomad-server-2:  <PUB_KEY_S2>
nomad-server-3:  <PUB_KEY_S3>
```

#### Step 6.3: Write WireGuard config on each node

Each node gets `/etc/wireguard/wg0.conf` with its own private key and all other nodes as peers.

**Template (example for ops-1 / 10.10.0.1):**
```ini
[Interface]
Address = 10.10.0.1/24
ListenPort = 51820
PrivateKey = <PRIVATE_KEY_OPS>

[Peer]
# nomad-server-1
PublicKey = <PUB_KEY_S1>
AllowedIPs = 10.10.0.2/32
Endpoint = 10.0.1.212:51820

[Peer]
# nomad-server-2
PublicKey = <PUB_KEY_S2>
AllowedIPs = 10.10.0.3/32
Endpoint = 10.0.1.144:51820

[Peer]
# nomad-server-3
PublicKey = <PUB_KEY_S3>
AllowedIPs = 10.10.0.4/32
Endpoint = 10.0.1.205:51820
```

**IP assignments:**
| Node | VPC IP | WireGuard IP | Role |
|------|--------|-------------|------|
| ops-1 | 10.0.1.131 | 10.10.0.1 | Monitoring, future Netmaker |
| nomad-server-1 | 10.0.1.212 | 10.10.0.2 | Nomad server (leader) |
| nomad-server-2 | 10.0.1.144 | 10.10.0.3 | Nomad server |
| nomad-server-3 | 10.0.1.205 | 10.10.0.4 | Nomad server |

**For each node**, adjust:
- `Address` = that node's WireGuard IP
- `PrivateKey` = that node's private key
- `[Peer]` sections = the other 3 nodes

```bash
# Write the config (example for ops-1, adjust per node)
sudo tee /etc/wireguard/wg0.conf << 'EOF'
[Interface]
Address = 10.10.0.1/24
ListenPort = 51820
PrivateKey = <PRIVATE_KEY_OPS>

[Peer]
# nomad-server-1
PublicKey = <PUB_KEY_S1>
AllowedIPs = 10.10.0.2/32
Endpoint = 10.0.1.212:51820

[Peer]
# nomad-server-2
PublicKey = <PUB_KEY_S2>
AllowedIPs = 10.10.0.3/32
Endpoint = 10.0.1.144:51820

[Peer]
# nomad-server-3
PublicKey = <PUB_KEY_S3>
AllowedIPs = 10.10.0.4/32
Endpoint = 10.0.1.205:51820
EOF

sudo chmod 600 /etc/wireguard/wg0.conf
```

#### Step 6.4: Enable and start WireGuard on all nodes

```bash
# On each node:
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0
```

**Verify interface is up:**
```bash
for h in ops-1 nomad-server-1 nomad-server-2 nomad-server-3; do
  echo "=== $h ==="
  ssh $h 'sudo wg show wg0 | head -6'
done
```

#### Step 6.5: Cross-node ping test

```bash
# From ops-1, ping all servers on WireGuard IPs
ssh ops-1 'ping -c 2 10.10.0.2 && ping -c 2 10.10.0.3 && ping -c 2 10.10.0.4'

# From server-1, ping the others
ssh nomad-server-1 'ping -c 2 10.10.0.1 && ping -c 2 10.10.0.3 && ping -c 2 10.10.0.4'
```

**Block 6 DONE when:** All 4 nodes show `wg show wg0` with active peers and can ping each other on 10.10.0.X IPs.

---

### Block 7: Reconfigure Nomad to WireGuard IPs

**Status: TODO — After Block 6**

Same as Progress-1.md Block 7, but with known WireGuard IPs:

| Node | WG IP |
|------|-------|
| nomad-server-1 | 10.10.0.2 |
| nomad-server-2 | 10.10.0.3 |
| nomad-server-3 | 10.10.0.4 |

#### Step 7.1: Update Nomad config on each server

Edit `/etc/nomad.d/nomad.hcl` on each server — change `advertise` block:

**nomad-server-1:**
```hcl
advertise {
  http = "10.10.0.2:4646"
  rpc  = "10.10.0.2:4647"
  serf = "10.10.0.2:4648"
}

server {
  enabled          = true
  bootstrap_expect = 3
  encrypt          = "EXISTING_GOSSIP_KEY"

  server_join {
    retry_join = ["10.10.0.2:4648", "10.10.0.3:4648", "10.10.0.4:4648"]
  }
}
```

Repeat for server-2 (10.10.0.3) and server-3 (10.10.0.4), changing only the `advertise` IPs.

#### Step 7.2: Rolling restart

```bash
# Non-leaders first, leader last
ssh nomad-server-3 'sudo systemctl restart nomad'
# wait 10s, check: ssh nomad-server-1 'nomad server members'

ssh nomad-server-2 'sudo systemctl restart nomad'
# wait 10s, check: ssh nomad-server-1 'nomad server members'

ssh nomad-server-1 'sudo systemctl restart nomad'
# wait 15s, check: ssh nomad-server-1 'nomad server members'
```

#### Step 7.3: Verify

```bash
ssh nomad-server-1 'nomad server members'
# All 3 should show 10.10.0.X addresses

ssh nomad-server-1 'nomad operator raft list-peers'
# 3 voters, 1 leader, WG IPs
```

**Rollback:** Revert advertise IPs to VPC IPs, stop all 3, start all 3.

**Block 7 DONE when:** `nomad server members` shows all 3 alive on WireGuard IPs.

---

### Block 5 (Revisit): Fix Prometheus

**Status: TODO — After Block 7**

ops-1 was recreated (SG issue), so monitoring stack needs redeployment.

```bash
# 1. Re-mount EBS volume
ssh ops-1 'lsblk'  # identify the volume
ssh ops-1 'sudo mkdir -p /mnt/prometheus-data'
# mount + fstab as before

# 2. Fix permissions
ssh ops-1 'sudo chown -R 65534:65534 /mnt/prometheus-data'

# 3. Deploy monitoring stack
# scp the docker-compose.yml and prometheus.yml to ops-1
scp -o ProxyJump=bastion-meridian monitoring/docker-compose.yml ops-1:/tmp/
scp -o ProxyJump=bastion-meridian monitoring/prometheus/prometheus.yml ops-1:/tmp/

ssh ops-1 'sudo mkdir -p /opt/monitoring/prometheus && sudo mv /tmp/docker-compose.yml /opt/monitoring/ && sudo mv /tmp/prometheus.yml /opt/monitoring/prometheus/'

# 4. Update prometheus.yml targets to WireGuard IPs
# Edit on ops-1: targets should be 10.10.0.2:4646, 10.10.0.3:4646, 10.10.0.4:4646

# 5. Start
ssh ops-1 'cd /opt/monitoring && sudo docker compose up -d'
```

**Verify:**
```bash
ssh -L 9090:10.0.1.131:9090 bastion-meridian -N &
curl -s http://127.0.0.1:9090/api/v1/targets | jq '.data.activeTargets[] | {instance, health}'
```

---

### Block 8: End-to-End Validation

**Status: TODO — Final**

- [ ] WireGuard mesh: all 4 nodes ping each other on 10.10.0.X
- [ ] Nomad cluster: 3 servers alive on WireGuard IPs
- [ ] Prometheus: scraping 3 Nomad servers via WG IPs, targets healthy
- [ ] Grafana: dashboard visible with metrics
- [ ] SSH: all access works via bastion
- [ ] Kill 1 Nomad server -> cluster survives -> restart -> rejoins
- [ ] Kill WireGuard on 1 server -> Nomad detects failure -> restart WG -> Nomad recovers

---

## Netmaker vs Plain WireGuard — When to Switch

| Criteria | Plain WireGuard (now) | Netmaker (later) |
|----------|----------------------|------------------|
| Node count | 4-10 nodes | 40+ nodes |
| Peer management | Manual (edit wg0.conf) | Automatic (enrollment token) |
| IP rotation | Manual WG reconfig | Auto-detect via STUN |
| Requirements | Just WireGuard | Public domain + TLS + Docker |
| When to switch | - | When on OCI with a domain, or when agents exceed ~10 nodes |

**Trigger to switch:** When the first batch of Alibaba agents needs to join the mesh. At that point, set up Netmaker on OCI ops-1 with a proper domain.

---

## Session Log

| Date | What was done | Blocks completed |
|------|---------------|-----------------|
| 2026-03-06 | SG fix (targeted destroy/recreate ops), Netmaker attempt failed (Caddy TLS), pivoted to plain WireGuard plan | Block 6 replanned |

---

## Notes

- ops-1 was recreated — new private IP is `10.0.1.131` (was `10.0.1.97`)
- Monitoring stack (Grafana/Prometheus) needs redeployment on new ops-1
- EBS volume survives instance recreation — just needs remount
- WireGuard CIDR narrowed to `10.10.0.0/24` (only 4 nodes for now, /16 reserved for future Netmaker)
- Security groups already have UDP 51820 open on both `ops` and `instance_base` SGs
