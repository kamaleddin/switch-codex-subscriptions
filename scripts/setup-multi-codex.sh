#!/usr/bin/env bash
set -euo pipefail

root="${CODEX_MULTI_ROOT:-$HOME/.codex-multi-account}"
shared_home="${CODEX_SHARED_HOME:-$HOME/.codex}"
accounts="${CODEX_MULTI_ACCOUNTS:-3}"
auth_dir="$root/auth"

mkdir -p "$auth_dir" "$root/homes" "$shared_home"

valid_account() {
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
}

account_list() {
  if [[ "$accounts" =~ ^[0-9]+$ ]]; then
    seq 1 "$accounts"
  else
    printf '%s\n' "$accounts" | tr ', ' '\n\n' | sed '/^$/d'
  fi
}

copy_auth_if_missing() {
  local source="$1"
  local dest="$2"

  if [[ -f "$source" && ! -f "$dest" ]]; then
    cp -p "$source" "$dest"
    chmod 600 "$dest" 2>/dev/null || true
  fi
}

for account in $(account_list); do
  if ! valid_account "$account"; then
    echo "Skipping invalid account id from CODEX_MULTI_ACCOUNTS: $account" >&2
    continue
  fi

  home="$root/homes/account-$account"
  slot="$auth_dir/account-$account.json"

  mkdir -p "$home/sessions" "$home/archived_sessions"

  copy_auth_if_missing "$home/auth.json" "$slot"
done

for home in "$root"/homes/account-*; do
  if [[ ! -d "$home" ]]; then
    continue
  fi

  account="$(basename "$home")"
  account="${account#account-}"
  if valid_account "$account"; then
    copy_auth_if_missing "$home/auth.json" "$auth_dir/account-$account.json"
  fi
done

copy_auth_if_missing "$shared_home/auth.json" "$auth_dir/account-1.json"

cat <<EOF
Configured multi-account Codex auth slots at:
  $auth_dir

Shared Codex home:
  $shared_home

Use:
  codex-account 1 login status
  codex-account 2 resume --last
  codex-account 3 --model gpt-5.4-mini
  CODEX_MULTI_ACCOUNTS="1,2,3,work" codex-accounts-setup
  codex-accounts-status
EOF
