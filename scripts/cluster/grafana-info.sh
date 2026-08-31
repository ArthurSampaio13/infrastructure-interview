#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/utils/common.sh
source "$(dirname "$0")/../utils/common.sh"

echo "url:      https://grafana.local.test"
echo "user:     admin"
printf 'password: '
kubectl -n monitoring get secret kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d
echo
