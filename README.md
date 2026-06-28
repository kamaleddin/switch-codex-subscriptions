# Multiple Codex Accounts

Switch between multiple ChatGPT/OpenAI subscriptions in Codex CLI while keeping
Codex capabilities shared.

The current strategy is auth-slot switching:

- One canonical Codex home: `~/.codex`.
- Shared sessions, skills, MCP servers, hooks, plugins, config, and agents.
- One saved auth file per subscription under `~/.codex-multi-account/auth`.
- A wrapper copies the selected auth slot into `~/.codex/auth.json`, runs
  `codex`, then copies refreshed credentials back to the slot.

This avoids duplicating Codex homes, which is what caused skills/MCP/hooks to
load inconsistently.

## Live State

Secrets and live Codex state are stored outside this synced repo:

```text
~/.codex/
  auth.json
  config.toml
  sessions/
  skills/
  hooks/
  agents/
  plugins/

~/.codex-multi-account/
  auth/
    account-1.json
    account-2.json
    account-3.json
  backups/
  homes/
    account-1/        # legacy import source only
    account-2/        # legacy import source only
    account-3/        # legacy import source only
```

Treat every `auth.json` and `account-*.json` file as a password.

## Setup

From this repo:

```bash
./scripts/setup-multi-codex.sh
```

Check account slots:

```bash
./scripts/status.sh
```

Create a backup before experiments or upgrades:

```bash
./scripts/backup-auth.sh
```

## Use An Account

Run Codex under a selected account:

```bash
codex-account 1
codex-account 2
codex-account 3
```

Run a direct Codex subcommand:

```bash
codex-account 2 login status
codex-account 3 resume --last
codex-account 1 mcp list
```

Because `~/.codex` is shared, normal resume does not need transcript copying:

```bash
codex-account 2 resume --last
```

After a switch, plain `codex` uses whichever account is currently active in
`~/.codex/auth.json`.

## Install Global Commands

The recommended install is symlinks into `~/.local/bin`, so pulling updates in
this repo updates the global commands automatically:

```bash
mkdir -p ~/.local/bin

ln -sf /Users/kamal/CloudStation/Dev/multiple-codex-accounts/scripts/cx ~/.local/bin/codex-account
ln -sf /Users/kamal/CloudStation/Dev/multiple-codex-accounts/scripts/switch-session.sh ~/.local/bin/codex-switch
ln -sf /Users/kamal/CloudStation/Dev/multiple-codex-accounts/scripts/status.sh ~/.local/bin/codex-accounts-status
ln -sf /Users/kamal/CloudStation/Dev/multiple-codex-accounts/scripts/setup-multi-codex.sh ~/.local/bin/codex-accounts-setup
ln -sf /Users/kamal/CloudStation/Dev/multiple-codex-accounts/scripts/backup-auth.sh ~/.local/bin/codex-accounts-backup
ln -sf /Users/kamal/CloudStation/Dev/multiple-codex-accounts/scripts/repair-codex-home.sh ~/.local/bin/codex-repair-home
```

Make sure `~/.local/bin` is in your shell path:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Legacy Transcript Import

`codex-switch` is no longer needed for normal resume. It exists for importing
old transcripts from legacy per-account homes and optionally launching resume.

Resume the latest shared transcript under account 2:

```bash
codex-switch --to 2 --latest
```

Import from a legacy account home:

```bash
codex-switch --from 1 --to 2 --latest --copy-only
```

Dry-run without copying or launching:

```bash
codex-switch --to 2 --latest --dry-run
```

## Add More Accounts

Numeric and named account ids are supported:

```bash
CODEX_MULTI_ACCOUNTS="1,2,3,work" codex-accounts-setup
codex-account work login
codex-account work login status
```

Account ids may contain letters, numbers, dots, underscores, and hyphens.

## Operational Rules

- Back up auth before changing login state: `codex-accounts-backup`.
- Do not run two different `codex-account` sessions concurrently. The wrapper
  uses a lock because all accounts share one active `~/.codex/auth.json`.
- Use plain `codex resume --last` only when the currently active account is the
  one you intend to use.
- Use `codex-account <account> resume --last` when switching and resuming in
  one command.
