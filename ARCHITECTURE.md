# Architecture

## Strategy

The architecture uses isolated account homes and explicit transcript copying.

Earlier we tested shared `sessions/` symlinks. That works at the filesystem
level, but it couples every account home to one shared mutable transcript store.
The copy-on-switch approach is safer:

- Auth remains isolated.
- Runtime/config state remains isolated.
- Session movement is explicit and auditable.
- A future Codex change to session indexing is less likely to corrupt all
  accounts at once.

## Components

### Account Homes

Each account home is a separate `CODEX_HOME`:

```text
~/.codex-multi-account/homes/account-N
```

Each home owns:

- `auth.json`
- `config.toml`
- `sessions/`
- `archived_sessions/`
- account-local logs/cache/temp state

### Account Config

Each account config includes:

```toml
cli_auth_credentials_store = "file"
model = "gpt-5.5"

[features]
goals = true
```

`cli_auth_credentials_store = "file"` keeps accounts from merging through the
OS keychain. `features.goals = true` keeps this install on the modern Codex
command surface.

### Wrapper

`scripts/cx` runs Codex under a selected account home:

```bash
./scripts/cx 1
./scripts/cx 2 login status
./scripts/cx 3 resume --last
```

### Switch Script

`scripts/switch-session.sh` resolves a transcript from the source account,
copies it into the target account using the same relative path under
`sessions/`, then optionally launches:

```bash
CODEX_HOME=<target-home> codex resume <session-id>
```

If the destination transcript already exists and differs, the script backs it
up before overwriting it.

## Transcript Resolution

`--latest` means newest `*.jsonl` by file modification time under the source
account's `sessions/`.

`--session <value>` accepts:

- A full path to a transcript file.
- A transcript filename.
- A session id substring such as `019ed1f4-3234-70a1-a259-148996cc666a`.

## Supported Account Selectors

- `default` or `0`: `~/.codex`
- `1`: `~/.codex-multi-account/homes/account-1`
- `2`: `~/.codex-multi-account/homes/account-2`
- `3`: `~/.codex-multi-account/homes/account-3`

## Risk Model

This is still based on Codex's local transcript files, but the blast radius is
smaller than shared symlinks. If a future Codex release changes transcript
layout, the switch script can be updated without untangling shared mutable
state across accounts.
