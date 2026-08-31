#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/chaos/lib.sh
source "$(dirname "$0")/lib.sh"

start_load
for _ in $(seq 1 8); do
  victim=$(kubectl -n posts-api get pods -l app.kubernetes.io/name=posts-api \
    -o name | shuf -n1 | cut -d/ -f2)
  log "deleting $victim"
  kubectl -n posts-api delete pod "$victim" --wait=false
  sleep 10
done
finish_load "random pod kill"
