#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
account_cmd="${CODEX_ACCOUNT_CMD:-}"
root="${CODEX_MULTI_ROOT:-$HOME/.codex-multi-account}"
shared_home="${CODEX_SHARED_HOME:-$HOME/.codex}"
from="default"
to=""
session=""
latest=false
copy_only=false
dry_run=false
extra_args=()

usage() {
  cat <<'USAGE'
Usage:
  switch-session.sh --to ACCOUNT [--latest | --session ID_OR_PATH] [options] [-- codex resume args...]

Accounts:
  Any saved auth profile id, such as 1, 2, 3, or work.

Transcript sources:
  default       Shared ~/.codex sessions, the normal source.
  0             Alias for default.
  ACCOUNT       Legacy per-account session folder under ~/.codex-multi-account.

Options:
  --from SOURCE         Transcript source. Default: default.
  --latest              Resume the newest transcript from the source.
  --session ID_OR_PATH  Resume a specific transcript by id, filename, or path.
  --copy-only           Import the transcript into shared ~/.codex, but do not launch Codex.
  --dry-run             Print what would happen without copying or launching.
  -h, --help            Show this help.

Examples:
  switch-session.sh --to 2 --latest
  switch-session.sh --to 2 --session 019ed1f4-3234-70a1-a259-148996cc666a
  switch-session.sh --from 1 --to 2 --latest
  switch-session.sh --from 1 --to 2 --latest --copy-only
  switch-session.sh --to 3 --latest -- --model gpt-5.4-mini
  switch-session.sh --to work --latest
USAGE
}

resolve_account_cmd() {
  if [[ -n "$account_cmd" ]]; then
    printf '%s\n' "$account_cmd"
    return 0
  fi

  if command -v codex-account >/dev/null 2>&1; then
    command -v codex-account
    return 0
  fi

  printf '%s\n' "$script_dir/cx"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from)
      from="${2:-}"
      shift 2
      ;;
    --to)
      to="${2:-}"
      shift 2
      ;;
    --latest)
      latest=true
      shift
      ;;
    --session)
      session="${2:-}"
      shift 2
      ;;
    --copy-only)
      copy_only=true
      shift
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      extra_args=("$@")
      break
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

valid_account() {
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
}

auth_account() {
  if valid_account "$1"; then
    printf '%s\n' "$1"
    return 0
  fi

  echo "Unsupported target account id: $1" >&2
  echo "Use letters, numbers, dots, underscores, or hyphens. Do not use paths." >&2
  exit 2
}

source_home() {
  case "$1" in
    default|0)
      printf '%s\n' "$shared_home"
      ;;
    *)
      if ! valid_account "$1"; then
        echo "Unsupported transcript source id: $1" >&2
        exit 2
      fi
      printf '%s\n' "$root/homes/account-$1"
      ;;
  esac
}

mtime() {
  stat -f '%m' "$1" 2>/dev/null || stat -c '%Y' "$1"
}

latest_transcript() {
  local sessions_dir="$1"

  find "$sessions_dir" -type f -name '*.jsonl' -print0 |
    while IFS= read -r -d '' file; do
      printf '%s\t%s\n' "$(mtime "$file")" "$file"
    done |
    sort -nr |
    head -n 1 |
    cut -f2-
}

find_session() {
  local sessions_dir="$1"
  local selector="$2"

  if [[ -f "$selector" ]]; then
    printf '%s\n' "$selector"
    return 0
  fi

  local matches
  matches="$(
    find "$sessions_dir" -type f -name '*.jsonl' -print |
      awk -v selector="$selector" 'index($0, selector) > 0'
  )"

  local count
  count="$(printf '%s\n' "$matches" | sed '/^$/d' | wc -l | tr -d ' ')"

  case "$count" in
    0)
      echo "No transcript matched '$selector' under $sessions_dir" >&2
      exit 1
      ;;
    1)
      printf '%s\n' "$matches"
      ;;
    *)
      echo "Multiple transcripts matched '$selector':" >&2
      printf '%s\n' "$matches" >&2
      exit 1
      ;;
  esac
}

session_id_from_path() {
  local file="$1"
  local base
  base="$(basename "$file" .jsonl)"

  if [[ "$base" =~ ^rollout-[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}-(.+)$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  else
    printf '%s\n' "$base"
  fi
}

if [[ -z "$to" ]]; then
  echo "--to is required." >&2
  usage >&2
  exit 2
fi

target_account="$(auth_account "$to")"
account_cmd="$(resolve_account_cmd)"

if [[ "$latest" == true && -n "$session" ]]; then
  echo "Use either --latest or --session, not both." >&2
  exit 2
fi

if [[ "$latest" == false && -z "$session" ]]; then
  latest=true
fi

from_home="$(source_home "$from")"
from_sessions="$from_home/sessions"
shared_sessions="$shared_home/sessions"

if [[ ! -d "$from_sessions" ]]; then
  echo "Missing source sessions directory: $from_sessions" >&2
  exit 1
fi

if [[ "$latest" == true ]]; then
  src="$(latest_transcript "$from_sessions")"
  if [[ -z "$src" ]]; then
    echo "No transcripts found under $from_sessions" >&2
    exit 1
  fi
else
  src="$(find_session "$from_sessions" "$session")"
fi

case "$src" in
  "$from_sessions"/*)
    rel="${src#"$from_sessions"/}"
    ;;
  *)
    rel="$(basename "$src")"
    ;;
esac

dest="$shared_sessions/$rel"
session_id="$(session_id_from_path "$src")"

echo "Transcript source: $from ($from_home)"
echo "Target account: $target_account"
echo "Shared Codex home: $shared_home"
echo "Transcript: $src"
echo "Shared destination: $dest"
echo "Session ID: $session_id"

if [[ "$dry_run" == true ]]; then
  if [[ "$src" != "$dest" ]]; then
    echo "Would import transcript into shared Codex home."
  fi
  if [[ "$copy_only" == false ]]; then
    echo "Would launch: $account_cmd $target_account resume $session_id ${extra_args[*]}"
  fi
  exit 0
fi

if [[ "$src" != "$dest" ]]; then
  mkdir -p "$(dirname "$dest")"

  if [[ -e "$dest" ]] && ! cmp -s "$src" "$dest"; then
    backup="$dest.backup.$(date +%Y%m%d-%H%M%S)"
    cp -p "$dest" "$backup"
    echo "Backed up existing shared transcript to: $backup"
  fi

  if [[ ! -e "$dest" ]] || ! cmp -s "$src" "$dest"; then
    cp -p "$src" "$dest"
    echo "Imported transcript into shared Codex home."
  else
    echo "Shared transcript is already identical."
  fi
else
  echo "Transcript already lives in shared Codex home."
fi

if [[ "$copy_only" == true ]]; then
  exit 0
fi

exec "$account_cmd" "$target_account" resume "$session_id" "${extra_args[@]}"
