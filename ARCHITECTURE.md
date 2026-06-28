# Architecture

## Strategy

The architecture uses one shared Codex home and multiple saved auth slots.

This is intentionally different from separate `CODEX_HOME` directories per
account. Separate homes isolate auth, but they also isolate skills, MCP
servers, hooks, plugins, agents, config, and sessions. That made account
switching fragile because a capability installed in one home might not exist in
another.

The shared-home design keeps Codex itself stable:

- `CODEX_HOME` is always `~/.codex`.
- Codex config and capabilities are loaded from one place.
- Sessions are shared naturally, so resume does not require transcript copy.
- Only authentication changes when switching accounts.

## Components

### Shared Codex Home

`~/.codex` owns the real Codex runtime state:

- `auth.json`
- `config.toml`
- `sessions/`
- `archived_sessions/`
- `skills/`
- `hooks/`
- `agents/`
- `plugins/`
- logs, cache, and other Codex-managed state

### Auth Slots

Each subscription has one file:

```text
~/.codex-multi-account/auth/account-<id>.json
```

The active account is whichever slot currently matches:

```text
~/.codex/auth.json
```

### Wrapper

`scripts/cx` is installed as `codex-account`.

For `codex-account 2 resume --last`, it:

1. Acquires `~/.codex-multi-account/active.lock`.
2. Backs up the active auth and selected slot.
3. Copies `account-2.json` to `~/.codex/auth.json`.
4. Runs `codex resume --last` with `CODEX_HOME=~/.codex`.
5. Copies the refreshed `~/.codex/auth.json` back to `account-2.json`.
6. Releases the lock.

If Codex removes `auth.json`, the wrapper preserves the saved auth slot instead
of deleting it.

### Setup

`scripts/setup-multi-codex.sh` creates the auth-slot directory and seeds slots
from legacy account homes when present. It does not overwrite existing slots.

### Status

`scripts/status.sh` discovers all `account-*.json` slots dynamically and shows
which one is currently active.

### Backup

`scripts/backup-auth.sh` copies active, slot, and legacy auth files into:

```text
~/.codex-multi-account/backups/auth-YYYYMMDD-HHMMSS/
```

It prints filenames only, not token contents.

### Repair

`scripts/repair-codex-home.sh` materializes important top-level symlinks in
`~/.codex` into real files/directories. This is useful after experiments that
linked `skills`, `hooks`, or `agents` to a per-account home.

### Legacy Transcript Switcher

`scripts/switch-session.sh` remains as `codex-switch` for compatibility and
legacy import:

- Default source is shared `~/.codex/sessions`.
- `--from <account>` imports from legacy
  `~/.codex-multi-account/homes/account-<account>/sessions`.
- `--copy-only` imports without launching Codex.
- `--dry-run` is read-only.

Normal resume should use `codex-account <account> resume --last`.

## Risk Model

This design depends on Codex continuing to support file-based auth at
`$CODEX_HOME/auth.json`. It avoids depending on duplicated skills, MCP config,
plugin caches, or session directories.

Main caveat: only one account-switched Codex session should run at a time,
because all accounts share one active `~/.codex/auth.json`.
