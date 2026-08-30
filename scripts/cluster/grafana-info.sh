#!/usr/bin/env bash
set -euo pipefail

echo "url:      https://grafana.local.test"
echo "user:     admin"
printf 'password: '
kubectl -n monitoring get secret kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d
echo
