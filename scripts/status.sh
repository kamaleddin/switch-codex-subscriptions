#!/usr/bin/env bash
set -euo pipefail

root="${CODEX_MULTI_ROOT:-$HOME/.codex-multi-account}"
shared_home="${CODEX_SHARED_HOME:-$HOME/.codex}"
auth_dir="$root/auth"
active_auth="$shared_home/auth.json"

found=false

for slot in "$auth_dir"/account-*.json; do
  if [[ ! -f "$slot" ]]; then
    continue
  fi

  found=true
  account="$(basename "$slot")"
  account="${account#account-}"
  account="${account%.json}"

  slot="$auth_dir/account-$account.json"
  echo "== account-$account =="

  if [[ ! -f "$slot" ]]; then
    echo "No auth slot."
    echo
    continue
  fi

  if [[ -f "$active_auth" ]] && cmp -s "$slot" "$active_auth"; then
    echo "Auth slot present. Active in $shared_home."
    CODEX_HOME="$shared_home" codex login status || true
  else
    echo "Auth slot present. Not currently active."
  fi

  echo
done

if [[ "$found" == false ]]; then
  echo "No auth slots found at: $auth_dir"
  echo "Run codex-accounts-setup, or create one with: codex-account 1 login"
fi
