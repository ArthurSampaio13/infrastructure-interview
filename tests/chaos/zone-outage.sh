#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/chaos/lib.sh
source "$(dirname "$0")/lib.sh"

# zone-a holds the host port mapping; kube-proxy keeps forwarding on a
# drained node, so any zone works. Default to zone-b for a clean read.
ZONE="${1:-zone-b}"
mapfile -t NODES < <(kubectl get nodes -l "topology.kubernetes.io/zone=$ZONE" -o name)
[[ ${#NODES[@]} -gt 0 ]] || die "no nodes in $ZONE"

# An interrupted run must never leave a node cordoned: uncordon on any exit.
trap 'for n in "${NODES[@]}"; do kubectl uncordon "$n"; done' EXIT

start_load
log "draining ${#NODES[@]} node(s) in $ZONE"
for n in "${NODES[@]}"; do kubectl cordon "$n"; done
for n in "${NODES[@]}"; do
  kubectl drain "$n" --ignore-daemonsets --delete-emptydir-data --timeout=180s
done
log "$ZONE down; app replica from that zone stays Pending until the zone returns"
finish_load "zone outage ($ZONE)"

log "$ZONE restored"

log "waiting for mysql InnoDBCluster to report ONLINE 3"
for _ in $(seq 1 30); do
  online=$(kubectl -n mysql get innodbcluster mysql -o jsonpath='{.status.cluster.status}' 2>/dev/null || true)
  [[ "$online" == "ONLINE" ]] && kubectl -n mysql get innodbcluster mysql -o jsonpath='{.status.cluster.onlineInstances}' | grep -qx 3 && break
  sleep 10
done

log "waiting for posts-api rollout to report 3/3 ready"
kubectl -n posts-api rollout status deployment posts-api --timeout=180s

log "recovery confirmed: mysql ONLINE 3, posts-api 3/3"
