#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/chaos/lib.sh
source "$(dirname "$0")/lib.sh"

pw=$(kubectl -n mysql get secret mysql-root -o jsonpath='{.data.rootPassword}' | base64 -d)
primary_query="SELECT MEMBER_HOST FROM performance_schema.replication_group_members WHERE MEMBER_ROLE='PRIMARY'"
primary=$(kubectl -n mysql exec mysql-0 -c mysql -- \
  mysql -uroot -p"$pw" -N -e "$primary_query" 2>/dev/null | cut -d. -f1)
[[ -n "$primary" ]] || die "could not determine the primary"
log "current primary: $primary"

start_load
kubectl -n mysql delete pod "$primary" --wait=false
log "primary deleted; group replication should elect a new one"
finish_load "mysql primary kill"

# Ask a member that was not the old primary; the old one may still be restarting.
survivor=$(kubectl -n mysql get pods -l mysql.oracle.com/cluster=mysql -o name |
  grep -v "pod/$primary\$" | head -n1 | cut -d/ -f2)
new_primary=$(kubectl -n mysql exec "$survivor" -c mysql -- \
  mysql -uroot -p"$pw" -N -e "$primary_query" 2>/dev/null | cut -d. -f1)
log "primary after failover: $new_primary"
[[ "$new_primary" != "$primary" ]] || die "primary did not change"
