#!/usr/bin/env bash
set -euo pipefail

# Retry terraform apply until ARM instances are provisioned.
# OCI free-tier ARM capacity is limited — this script polls until slots open.
#
# Usage:
#   ./scripts/oci-arm-retry.sh [interval_seconds] [max_attempts]
#
# Prerequisites:
#   - terraform.local.tfvars configured in oci/ (or use TF_VAR_* env vars)
#   - terraform init already run

INTERVAL="${1:-60}"
MAX_ATTEMPTS="${2:-0}" # 0 = infinite
ATTEMPT=0
TF_DIR="$(cd "$(dirname "$0")/../oci" && pwd)"
TF_VAR_FILE="${TF_DIR}/terraform.local.tfvars"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log "Starting OCI ARM retry loop (interval: ${INTERVAL}s, max: ${MAX_ATTEMPTS:-unlimited})"
log "Terraform directory: ${TF_DIR}"
if [[ -f "$TF_VAR_FILE" ]]; then
  log "Using var-file: ${TF_VAR_FILE}"
  TF_APPLY_ARGS=(-var-file="$TF_VAR_FILE")
else
  log "No ${TF_VAR_FILE} found; using TF_VAR_* / defaults only."
  TF_APPLY_ARGS=()
fi

while true; do
  ATTEMPT=$((ATTEMPT + 1))

  if [[ "$MAX_ATTEMPTS" -gt 0 && "$ATTEMPT" -gt "$MAX_ATTEMPTS" ]]; then
    log "FAILED: Reached max attempts ($MAX_ATTEMPTS). Giving up."
    exit 1
  fi

  log "Attempt #${ATTEMPT} — running terraform apply..."

  if terraform -chdir="$TF_DIR" apply -auto-approve "${TF_APPLY_ARGS[@]}" 2>&1 | tee /tmp/tf-retry-output.log; then
    log "SUCCESS: terraform apply completed!"
    exit 0
  fi

  if ! grep -q "Out of host capacity" /tmp/tf-retry-output.log; then
    log "FAILED: Error is NOT a capacity issue. Check /tmp/tf-retry-output.log"
    exit 2
  fi

  log "Out of host capacity. Retrying in ${INTERVAL}s..."
  sleep "$INTERVAL"
done
