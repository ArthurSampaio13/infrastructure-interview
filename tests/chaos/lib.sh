#!/usr/bin/env bash

# shellcheck source=scripts/utils/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/utils/common.sh"

start_load() {
  DURATION="${DURATION:-2m}" mise exec -- k6 run --quiet "$(dirname "${BASH_SOURCE[0]}")/../load/load.js" &
  K6_PID=$!
  sleep 10
}

finish_load() {
  local scenario="$1"
  if wait "$K6_PID"; then
    log "PASS: $scenario kept the SLO (error rate <1%, p95 <300ms)"
  else
    die "FAIL: $scenario violated the SLO"
  fi
}
