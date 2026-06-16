#!/usr/bin/env bash
set -euo pipefail

root="${CODEX_MULTI_ROOT:-$HOME/.codex-multi-account}"
from=""
to=""
session=""
latest=false
copy_only=false
dry_run=false
extra_args=()

usage() {
  cat <<'USAGE'
Usage:
  switch-session.sh --from ACCOUNT --to ACCOUNT [--latest | --session ID_OR_PATH] [options] [-- codex resume args...]

Accounts:
  default, 0  Use ~/.codex
  1           Use ~/.codex-multi-account/homes/account-1
  2           Use ~/.codex-multi-account/homes/account-2
  3           Use ~/.codex-multi-account/homes/account-3

Options:
  --latest              Copy the newest transcript from the source account.
  --session ID_OR_PATH  Copy a specific transcript by id, filename, or path.
  --copy-only           Copy the transcript but do not launch codex resume.
  --dry-run             Print what would happen without copying or launching.
  -h, --help            Show this help.

Examples:
  switch-session.sh --from 1 --to 2 --latest
  switch-session.sh --from default --to 2 --latest --copy-only
  switch-session.sh --from 1 --to 2 --session 019ed1f4-3234-70a1-a259-148996cc666a
  switch-session.sh --from 1 --to 2 --latest -- --model gpt-5.5
USAGE
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

account_home() {
  case "$1" in
    default|0)
      printf '%s\n' "$HOME/.codex"
      ;;
    1|2|3)
      printf '%s\n' "$root/homes/account-$1"
      ;;
    *)
      echo "Unsupported account selector: $1" >&2
      exit 2
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

if [[ -z "$from" || -z "$to" ]]; then
  echo "--from and --to are required." >&2
  usage >&2
  exit 2
fi

if [[ "$latest" == true && -n "$session" ]]; then
  echo "Use either --latest or --session, not both." >&2
  exit 2
fi

if [[ "$latest" == false && -z "$session" ]]; then
  latest=true
fi

from_home="$(account_home "$from")"
to_home="$(account_home "$to")"
from_sessions="$from_home/sessions"
to_sessions="$to_home/sessions"

if [[ ! -d "$from_sessions" ]]; then
  echo "Missing source sessions directory: $from_sessions" >&2
  exit 1
fi

if [[ ! -d "$to_home" ]]; then
  echo "Missing target account home: $to_home" >&2
  exit 1
fi

mkdir -p "$to_sessions"

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

dest="$to_sessions/$rel"
session_id="$(session_id_from_path "$src")"

echo "Source account: $from ($from_home)"
echo "Target account: $to ($to_home)"
echo "Transcript: $src"
echo "Destination: $dest"
echo "Session ID: $session_id"

if [[ "$dry_run" == true ]]; then
  if [[ "$copy_only" == false ]]; then
    echo "Would launch: CODEX_HOME=$to_home codex -c features.goals=true resume $session_id ${extra_args[*]}"
  fi
  exit 0
fi

mkdir -p "$(dirname "$dest")"

if [[ -e "$dest" ]] && ! cmp -s "$src" "$dest"; then
  backup="$dest.backup.$(date +%Y%m%d-%H%M%S)"
  cp -p "$dest" "$backup"
  echo "Backed up existing destination transcript to: $backup"
fi

if [[ ! -e "$dest" ]] || ! cmp -s "$src" "$dest"; then
  cp -p "$src" "$dest"
  echo "Copied transcript."
else
  echo "Destination transcript is already identical."
fi

if [[ "$copy_only" == true ]]; then
  exit 0
fi

export CODEX_HOME="$to_home"
exec codex -c features.goals=true resume "$session_id" "${extra_args[@]}"
