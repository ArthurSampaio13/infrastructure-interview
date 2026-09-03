#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/utils/common.sh
source "$(dirname "$0")/../utils/common.sh"

IMAGE="skizay/posts-api"
REGISTRY="public"
TAG="dev"

help() {
  cat <<USAGE
Usage: $0 [--image <repository>] [--registry public|private] [--tag <image-tag>]
USAGE
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --image)
      IMAGE="$2"
      shift 2
      ;;
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

repo="$IMAGE"
extra=()
case "$REGISTRY" in
  public) ;;
  private)
    repo="${IMAGE}-private"
    extra+=(--set "imagePullSecrets[0]=dockerhub")
    ;;
  *) die "unknown registry: $REGISTRY (public|private)" ;;
esac

log "deploying $repo:$TAG"
# ${arr[@]+"${arr[@]}"} keeps set -u happy on bash < 4.4 when the array is empty.
helm upgrade --install posts-api charts/posts-api \
  --namespace posts-api \
  -f values/posts-api/local.yaml \
  --set "image.repository=$repo" \
  --set "image.tag=$TAG" \
  --wait --timeout 5m ${extra[@]+"${extra[@]}"}
log "deployed"
