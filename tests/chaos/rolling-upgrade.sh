#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=tests/chaos/lib.sh
source "$(dirname "$0")/lib.sh"

start_load
# Same effect as a helm upgrade with a new tag: full rolling replacement.
kubectl -n posts-api rollout restart deployment posts-api
kubectl -n posts-api rollout status deployment posts-api --timeout=180s
finish_load "rolling upgrade"
