#!/usr/bin/env bash
# Firecracker REST API 小工具：fc_api METHOD PATH [JSON]
SOCK=${FC_SOCK:-/tmp/fc-lab05.sock}
fc_api() {
  local method=$1 path=$2 body=${3:-}
  if [[ -n $body ]]; then
    curl -sS --unix-socket "$SOCK" -X "$method" "http://localhost$path" \
      -H 'Content-Type: application/json' -d "$body"
  else
    curl -sS --unix-socket "$SOCK" -X "$method" "http://localhost$path"
  fi
}