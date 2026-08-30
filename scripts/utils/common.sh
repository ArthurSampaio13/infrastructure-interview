#!/usr/bin/env bash

log() { printf '%s %s\n' "$(date +%H:%M:%S)" "$*"; }
die() {
  log "error: $*" >&2
  exit 1
}
