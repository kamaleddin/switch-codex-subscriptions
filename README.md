# Multiple Codex Accounts

This folder documents and automates a safer setup for switching between
multiple OpenAI/Codex subscriptions.

The current strategy is copy-on-switch:

- Each subscription has its own isolated `CODEX_HOME`.
- Each account keeps its own real `sessions/` directory.
- When switching accounts, a script copies one transcript from the source
  account to the target account, then launches `codex resume` in the target.

This avoids permanently sharing Codex session directories through symlinks.

## Live State

Live Codex state is stored outside this synced workspace:

```text
~/.codex-multi-account/
  homes/
    account-1/
      auth.json
      config.toml
      sessions/
      archived_sessions/
    account-2/
      auth.json
      config.toml
      sessions/
      archived_sessions/
    account-3/
      config.toml
      sessions/
      archived_sessions/
```

`auth.json` files are secrets. They are intentionally kept out of
`CloudStation/Dev`.

## Setup

From this folder:

```bash
./scripts/setup-multi-codex.sh
./scripts/cx 1 login
./scripts/cx 2 login
./scripts/cx 3 login
```

Account 1 has already been seeded from the default `~/.codex/auth.json` on this
machine. Account 2 has already been authenticated through device login.

Check auth state:

```bash
./scripts/status.sh
```

## Use An Account

```bash
./scripts/cx 1
./scripts/cx 2
./scripts/cx 3 resume --last
```

## Install Global Commands

The recommended install is symlinks into `~/.local/bin`, so pulling updates in
this repo updates the global commands automatically:

```bash
mkdir -p ~/.local/bin

ln -sf /Users/kamal/CloudStation/Dev/multiple-codex-accounts/scripts/cx ~/.local/bin/codex-account
ln -sf /Users/kamal/CloudStation/Dev/multiple-codex-accounts/scripts/switch-session.sh ~/.local/bin/codex-switch
ln -sf /Users/kamal/CloudStation/Dev/multiple-codex-accounts/scripts/status.sh ~/.local/bin/codex-accounts-status
ln -sf /Users/kamal/CloudStation/Dev/multiple-codex-accounts/scripts/setup-multi-codex.sh ~/.local/bin/codex-accounts-setup
```

Make sure `~/.local/bin` is in your shell path:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

After that, the tools work from any folder:

```bash
codex-account 1
codex-account 2 login status
codex-switch --from 1 --to 2 --latest
codex-accounts-status
codex-accounts-setup
```

## Switch A Session

Copy the latest transcript from account 1 to account 2, then launch resume in
account 2:

```bash
./scripts/switch-session.sh --from 1 --to 2 --latest
```

Copy a specific transcript by session id, then launch it:

```bash
./scripts/switch-session.sh --from 1 --to 2 --session 019ed1f4-3234-70a1-a259-148996cc666a
```

Copy only, without launching Codex:

```bash
./scripts/switch-session.sh --from 1 --to 2 --latest --copy-only
```

Use the default `~/.codex` profile as a source:

```bash
./scripts/switch-session.sh --from default --to 2 --latest
```

Pass extra arguments to `codex resume` after `--`:

```bash
./scripts/switch-session.sh --from 1 --to 2 --latest -- --model gpt-5.5
```

## Shell Aliases

Optional `~/.zshrc` aliases:

```zsh
alias codex1='CODEX_HOME=$HOME/.codex-multi-account/homes/account-1 codex -c features.goals=true'
alias codex2='CODEX_HOME=$HOME/.codex-multi-account/homes/account-2 codex -c features.goals=true'
alias codex3='CODEX_HOME=$HOME/.codex-multi-account/homes/account-3 codex -c features.goals=true'
alias codex-switch='$HOME/CloudStation/Dev/multiple-codex-accounts/scripts/switch-session.sh'
alias codex-status='$HOME/CloudStation/Dev/multiple-codex-accounts/scripts/status.sh'
```

If you install the global commands above, these aliases are optional. The
global commands are clearer and less likely to collide with unrelated tools.

## Operational Rules

- Treat every `auth.json` as a password.
- Do not copy a transcript into a target account while that same session is
  already open in another terminal.
- Prefer `--session <id>` for important work so you know exactly what is being
  copied.
- If Codex upgrades change the session file layout, this copy-on-switch script
  is easier to repair than permanent shared-session symlinks.
