#!/usr/bin/env bash
set -euo pipefail

root="${CODEX_MULTI_ROOT:-$HOME/.codex-multi-account}"

for account in 1 2 3; do
  home="$root/homes/account-$account"
  echo "== account-$account =="
  if [[ ! -d "$home" ]]; then
    echo "missing home: $home"
    echo
    continue
  fi

  if output="$(CODEX_HOME="$home" codex login status 2>&1)"; then
    printf '%s\n' "$output"
  elif [[ "$output" == *"No such file or directory"* ]]; then
    echo "Not logged in yet."
  else
    printf '%s\n' "$output"
  fi
  echo
done
