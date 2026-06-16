#!/usr/bin/env bash
set -euo pipefail

root="${CODEX_MULTI_ROOT:-$HOME/.codex-multi-account}"
accounts="${CODEX_MULTI_ACCOUNTS:-3}"

ensure_session_dir() {
  local path="$1"

  if [[ -L "$path" ]]; then
    local current
    current="$(readlink "$path")"
    if [[ "$current" == ../../shared/* ]]; then
      rm "$path"
    else
      echo "Refusing to replace unexpected symlink: $path -> $current" >&2
      exit 1
    fi
  fi

  mkdir -p "$path"
}

ensure_feature_goals() {
  local config="$1"

  if ! grep -q '^\[features\]' "$config"; then
    cat >> "$config" <<'TOML'

[features]
goals = true
TOML
    return 0
  fi

  if ! awk '
    /^\[features\]$/ { in_features = 1; next }
    /^\[/ { in_features = 0 }
    in_features && /^goals[[:space:]]*=/ { found = 1 }
    END { exit found ? 0 : 1 }
  ' "$config"; then
    echo "Warning: $config has [features] but no goals setting; leaving it unchanged." >&2
  fi
}

mkdir -p "$root/homes"

for account in $(seq 1 "$accounts"); do
  home="$root/homes/account-$account"
  mkdir -p "$home"

  if [[ ! -e "$home/config.toml" ]]; then
    cat > "$home/config.toml" <<'TOML'
cli_auth_credentials_store = "file"
model = "gpt-5.5"

[features]
goals = true
TOML
  elif ! grep -q '^cli_auth_credentials_store *= *"file"' "$home/config.toml"; then
    cat >> "$home/config.toml" <<'TOML'

cli_auth_credentials_store = "file"
TOML
  fi

  if ! grep -q '^model *=' "$home/config.toml"; then
    cat >> "$home/config.toml" <<'TOML'
model = "gpt-5.5"
TOML
  fi

  ensure_feature_goals "$home/config.toml"
  ensure_session_dir "$home/sessions"
  ensure_session_dir "$home/archived_sessions"
done

cat <<EOF
Created multi-account Codex state at:
  $root

Try:
  $(pwd)/scripts/cx 1 login status
  $(pwd)/scripts/switch-session.sh --from 1 --to 2 --latest --copy-only

Optional aliases:
  alias codex1='CODEX_HOME=$root/homes/account-1 codex -c features.goals=true'
  alias codex2='CODEX_HOME=$root/homes/account-2 codex -c features.goals=true'
  alias codex3='CODEX_HOME=$root/homes/account-3 codex -c features.goals=true'
EOF
