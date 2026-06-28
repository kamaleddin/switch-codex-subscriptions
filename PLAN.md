# Plan

## Phase 1: Move To Shared Codex Home

- Use canonical `~/.codex` for sessions, skills, MCP, hooks, plugins, agents,
  and config.
- Stop running Codex with per-account `CODEX_HOME` values for normal use.
- Keep legacy account homes only as transcript import sources.

Status: implemented.

## Phase 2: Auth Slot Switching

- Store per-subscription auth files under `~/.codex-multi-account/auth`.
- Copy the selected slot into `~/.codex/auth.json` before launching Codex.
- Copy refreshed credentials back to the selected slot on exit.
- Use a lock to prevent concurrent switches from clobbering auth.
- Back up active and slot auth before each switch.

Status: implemented in `scripts/cx`.

## Phase 3: Shared Capability Repair

- Materialize accidental symlinks in `~/.codex` for skills, hooks, agents, and
  GSD files.
- Keep symlink backups with timestamped names.

Status: implemented in `scripts/repair-codex-home.sh` and run on this machine.

## Phase 4: Verification

Checks used:

```bash
bash -n scripts/cx
bash -n scripts/status.sh
bash -n scripts/setup-multi-codex.sh
bash -n scripts/switch-session.sh
bash -n scripts/repair-codex-home.sh
bash -n scripts/backup-auth.sh
codex-accounts-status
codex-account 2 login status
codex-account 3 login status
codex-account 2 mcp list
codex-account 1 login status
```

Expected result:

- All scripts parse.
- Accounts 1, 2, and 3 report `Logged in using ChatGPT`.
- MCP config is visible after switching accounts.
- Account 1 is restored as active after tests.

## Phase 5: Global Access

Install symlinks into `~/.local/bin` so the tools work from any directory:

```bash
codex-account
codex-switch
codex-accounts-status
codex-accounts-setup
codex-accounts-backup
codex-repair-home
```

Status: installed/updated on this machine.
