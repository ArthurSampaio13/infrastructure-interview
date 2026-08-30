#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/utils/common.sh
source "$(dirname "$0")/../utils/common.sh"

REGISTRY="public"
TAG="dev"

help() {
  cat <<USAGE
Usage: $0 [--registry public|private] [--tag <image-tag>]
USAGE
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --registry)
      REGISTRY="$2"
      shift 2
      ;;
    --tag)
      TAG="$2"
      shift 2
      ;;
    -h | --help)
      help
      exit 0
      ;;
    *) die "unknown flag: $1" ;;
  esac
done

repo="skizay/posts-api"
extra=()
if [[ "$REGISTRY" == "private" ]]; then
  repo="skizay/posts-api-private"
  extra+=(--set "imagePullSecrets[0]=dockerhub")
fi

log "deploying $repo:$TAG"
helm upgrade --install posts-api charts/posts-api \
  --namespace posts-api \
  -f values/posts-api/common.yaml \
  -f values/posts-api/local.yaml \
  --set "image.repository=$repo" \
  --set "image.tag=$TAG" \
  --wait --timeout 5m "${extra[@]}"
log "deployed"
