#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/utils/common.sh
source "$(dirname "$0")/../utils/common.sh"

NODE=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --node)
      NODE="$2"
      shift 2
      ;;
    *) die "usage: $0 --node <name>" ;;
  esac
done
[[ -n "$NODE" ]] || die "usage: $0 --node <name>"

log "draining $NODE (PodDisruptionBudgets are honored)"
if ! kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=300s; then
  die "drain blocked or timed out; check 'kubectl get pdb -A' before forcing anything"
fi
log "$NODE drained; run 'kubectl uncordon $NODE' after maintenance"
