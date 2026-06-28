#!/usr/bin/env bash
set -euo pipefail

root="${CODEX_MULTI_ROOT:-$HOME/.codex-multi-account}"
shared_home="${CODEX_SHARED_HOME:-$HOME/.codex}"
backup_dir="$root/backups/auth-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$backup_dir"
chmod 700 "$backup_dir" 2>/dev/null || true

copy_secret() {
  local source="$1"
  local name="$2"

  if [[ -f "$source" ]]; then
    cp -p "$source" "$backup_dir/$name"
    chmod 600 "$backup_dir/$name" 2>/dev/null || true
    echo "Backed up: $name"
  fi
}

copy_secret "$shared_home/auth.json" "active-auth.json"

for slot in "$root"/auth/account-*.json; do
  if [[ -f "$slot" ]]; then
    copy_secret "$slot" "$(basename "$slot")"
  fi
done

for legacy_auth in "$root"/homes/account-*/auth.json; do
  if [[ -f "$legacy_auth" ]]; then
    account="$(basename "$(dirname "$legacy_auth")")"
    copy_secret "$legacy_auth" "legacy-$account-auth.json"
  fi
done

echo "Auth backup directory: $backup_dir"
