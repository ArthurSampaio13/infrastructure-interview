#!/usr/bin/env bash

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/kind-interview.yaml}"

log() { printf '%s %s\n' "$(date +%H:%M:%S)" "$*"; }
die() {
  log "error: $*" >&2
  exit 1
}
