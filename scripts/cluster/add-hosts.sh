#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/utils/common.sh
source "$(dirname "$0")/../utils/common.sh"

for host in posts.local.test grafana.local.test; do
  if grep -q "$host" /etc/hosts; then
    log "$host already in /etc/hosts"
  else
    log "adding $host to /etc/hosts (sudo)"
    echo "127.0.0.1 $host" | sudo tee -a /etc/hosts >/dev/null
  fi
done
