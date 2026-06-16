# Plan

## Phase 1: Account Isolation

- Keep one `CODEX_HOME` per subscription.
- Force file-based auth cache in each account home.
- Use real account-local `sessions/` directories.

Status: implemented.

## Phase 2: Session Switching

- Resolve the latest transcript or a specific transcript from a source account.
- Copy it to the target account, preserving its relative `sessions/` path.
- Back up a differing destination transcript before overwriting.
- Launch `codex resume <session-id>` in the target account unless `--copy-only`
  is passed.

Status: implemented in `scripts/switch-session.sh`.

## Phase 3: Verification

Recommended checks:

```bash
./scripts/status.sh
./scripts/switch-session.sh --from default --to 2 --latest --copy-only
./scripts/switch-session.sh --from 1 --to 2 --session <session-id> --copy-only
```

Launch check:

```bash
./scripts/switch-session.sh --from 1 --to 2 --latest
```

## Phase 4: Maintenance

Before major Codex upgrades, back up account sessions:

```bash
tar -czf ~/codex-multi-account-backup-$(date +%Y%m%d-%H%M%S).tgz \
  -C ~/.codex-multi-account homes
```

## Phase 5: Global Access

Install symlinks into `~/.local/bin` so the tools work from any directory:

```bash
codex-account
codex-switch
codex-accounts-status
codex-accounts-setup
```

Status: installed on this machine.
