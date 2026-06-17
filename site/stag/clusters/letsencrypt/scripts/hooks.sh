#!/usr/bin/env bash
set -euo pipefail

deploy_challenge() {
  local DOMAIN="$1" TOKEN_FILENAME="$2" TOKEN_VALUE="$3"
  mkdir -p /var/lib/acme-webroot/.well-known/acme-challenge
  printf '%s' "$TOKEN_VALUE" \
    > "/var/lib/acme-webroot/.well-known/acme-challenge/$TOKEN_FILENAME"
}

clean_challenge() {
  local DOMAIN="$1" TOKEN_FILENAME="$2" TOKEN_VALUE="$3"
  rm -f "/var/lib/acme-webroot/.well-known/acme-challenge/$TOKEN_FILENAME"
}

deploy_cert() {
  local DOMAIN="$1" KEYFILE="$2" CERTFILE="$3" FULLCHAINFILE="$4" CHAINFILE="$5"
  kubectl -n demo create secret tls web-tls \
    --cert="$FULLCHAINFILE" --key="$KEYFILE" \
    --dry-run=client -o yaml | kubectl apply -f -
}

# Dispatcher: dehydrated calls this script as `hook.sh <operation> <args...>`
HANDLER="$1"; shift
if [ "$(type -t "$HANDLER" || true)" = "function" ]; then
  "$HANDLER" "$@"
fi