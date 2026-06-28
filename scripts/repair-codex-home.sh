#!/usr/bin/env bash
set -euo pipefail

shared_home="${CODEX_SHARED_HOME:-$HOME/.codex}"
timestamp="$(date +%Y%m%d-%H%M%S)"

materialize_symlink() {
  local path="$1"

  if [[ ! -L "$path" ]]; then
    return 0
  fi

  local target
  target="$(readlink "$path")"

  if [[ ! -e "$target" ]]; then
    echo "Broken symlink, leaving unchanged: $path -> $target" >&2
    return 1
  fi

  local backup="$path.symlink-backup.$timestamp"
  mv "$path" "$backup"

  if [[ -d "$target" ]]; then
    mkdir -p "$path"
    cp -RX "$target"/. "$path"/
  else
    cp -p "$target" "$path"
  fi

  echo "Materialized $path from $target"
  echo "Symlink backup: $backup"
}

materialize_symlink "$shared_home/skills"
materialize_symlink "$shared_home/agents"
materialize_symlink "$shared_home/hooks"
materialize_symlink "$shared_home/gsd-core"
materialize_symlink "$shared_home/gsd-file-manifest.json"
materialize_symlink "$shared_home/gsd-install-state.json"

echo "Codex home repair complete: $shared_home"
