#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/chaos/lib.sh
source "$(dirname "$0")/lib.sh"

# On kind the host ports are mapped on the zone-a node only (see docs/architecture.md, Cluster and zones),
# so draining zone-a would take the entry point down with it. Default to zone-b.
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

for n in "${NODES[@]}"; do kubectl uncordon "$n"; done
log "$ZONE restored"

log "waiting for mysql InnoDBCluster to report ONLINE 3"
online_ready=0
for _ in $(seq 1 30); do
  online=$(kubectl -n mysql get innodbcluster mysql -o jsonpath='{.status.cluster.status}' 2>/dev/null || true)
  [[ "$online" == "ONLINE" ]] && kubectl -n mysql get innodbcluster mysql -o jsonpath='{.status.cluster.onlineInstances}' | grep -qx 3 && {
    online_ready=1
    break
  }
  sleep 10
done
[[ "$online_ready" == 1 ]] || die "mysql InnoDBCluster did not reach ONLINE 3 within 300s"

log "waiting for posts-api to report all desired replicas ready"
ready=0
for _ in $(seq 1 60); do
  desired=$(kubectl -n posts-api get deploy posts-api -o jsonpath='{.spec.replicas}' || true)
  actual=$(kubectl -n posts-api get deploy posts-api -o jsonpath='{.status.readyReplicas}' || true)
  actual="${actual:-0}"
  [[ "$actual" == "$desired" ]] && {
    ready=1
    break
  }
  sleep 10
done
[[ "$ready" == 1 ]] || die "posts-api did not reach $desired/$desired ready replicas within 600s"

log "recovery confirmed: mysql ONLINE 3, posts-api 3/3"
