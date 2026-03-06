# Learning 1: SSH Access to AWS EC2 Instances — Troubleshooting

**Date:** 2026-03-05
**Context:** Migrated Meridian control plane from OCI to AWS (temporary). 5 EC2 instances (3 Nomad servers, 1 ops, 1 bastion) in ap-southeast-1 via Terraform.

---

## Problem

Could not SSH into any instance. Two distinct failures surfaced:

### Failure 1: "Too many authentication failures"

```
Received disconnect from 18.141.13.153 port 22:2: Too many authentication failures
```

**Root cause:** SSH agent had 4+ keys loaded. The bastion's cloud-init set `MaxAuthTries 3` in `/etc/ssh/sshd_config.d/99-hardening.conf`. SSH agent offered its keys in order; the correct key was never reached before the limit.

**Fix:** Added `IdentitiesOnly yes` to all meridian entries in `~/.ssh/config`. This forces SSH to only use the explicitly specified `IdentityFile`, ignoring all agent-offered keys.

### Failure 2: "Permission denied (publickey)"

```
debug1: Offering public key: ~/.ssh/meridian ED25519 SHA256:Mu83... explicit agent
debug1: Authentications that can continue: publickey
ubuntu@host: Permission denied (publickey).
```

**Root cause:** The `~/.ssh/meridian` keypair was generated **after** Terraform had already provisioned the instances. Terraform's `aws_key_pair` was then updated with the new public key (plan shows "no changes" because the replacement already happened), but EC2 only injects the key into `authorized_keys` **at first boot via cloud-init/metadata**. The running instances still had the **old** key baked in.

**Diagnosis:** Compared fingerprints:
- `aws ec2 describe-key-pairs` — showed new key fingerprint (Terraform had updated it)
- `aws ec2 get-console-output` — revealed the **boot-time** authorized key had a different fingerprint and comment (`meridian-key` vs `meridian-infra`)

**Fix:** Used `aws ec2-instance-connect send-ssh-public-key` to temporarily push the new key (60-second window), then appended it permanently to `~/.ssh/authorized_keys` on each instance.

### Failure 3: Bastion ProxyJump to internal nodes timed out

```
Connection timed out during banner exchange
```

**Root cause:** The `instance_base` security group only allowed SSH from `ssh_admin_cidr = "223.206.43.162/32"` (Win's home IP). When bastion ProxyJumps to internal nodes, the traffic originates from the bastion's **VPC private IP** (10.0.1.x), which didn't match the allowed CIDR.

**Fix:** Added a second SSH ingress rule to `instance_base` SG in `security.tf`:
```hcl
ingress {
  description = "SSH from VPC (bastion ProxyJump)"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = [var.vpc_cidr]
}
```

---

## Key Lessons

1. **EC2 key injection is boot-time only.** Changing `aws_key_pair` does NOT update running instances. You must either recreate the instances or use EC2 Instance Connect / SSM to push keys.

2. **`IdentitiesOnly yes` is essential** when your SSH agent has multiple keys and the server has a low `MaxAuthTries`. Always include it in SSH config entries.

3. **Bastion ProxyJump traffic originates from the bastion's private IP**, not from the original client's IP. Security groups must allow SSH from the VPC CIDR (or at minimum, the bastion's IP) for ProxyJump to work.

4. **`aws ec2 get-console-output`** is invaluable for debugging SSH issues — it shows the exact authorized key fingerprints injected at boot time.

5. **`aws ec2-instance-connect send-ssh-public-key`** provides a 60-second temporary key push — useful for emergency access without instance recreation. Must SSH immediately after pushing.

6. **`ssh -vvv`** debug output reveals whether the right key is being offered and whether the server accepts or rejects it. The `explicit agent` vs `explicit` distinction tells you if ssh-agent is involved.

---

## Commands Used

```bash
# Diagnose SSH agent key count
ssh-add -l

# Verbose SSH debug
ssh -vvv -o IdentitiesOnly=yes -i ~/.ssh/meridian ubuntu@HOST

# Check boot-time authorized keys from console output
aws ec2 get-console-output --instance-id INSTANCE_ID --region REGION --profile PROFILE \
  | grep -i authorized_keys

# Compare key fingerprints
aws ec2 describe-key-pairs --key-names KEY_NAME --query 'KeyPairs[0].KeyFingerprint'
ssh-keygen -lf ~/.ssh/meridian.pub

# Emergency key push (60-second window)
aws ec2-instance-connect send-ssh-public-key \
  --instance-id INSTANCE_ID \
  --instance-os-user ubuntu \
  --ssh-public-key file://~/.ssh/meridian.pub

# Persist key after temporary push
ssh USER@HOST "echo 'PUBLIC_KEY' >> ~/.ssh/authorized_keys"
```

---

## Files Modified

- `aws/security.tf` — Added VPC CIDR SSH ingress to `instance_base` SG
- `~/.ssh/config` — Added `IdentitiesOnly yes` to all meridian hosts, fixed indentation
