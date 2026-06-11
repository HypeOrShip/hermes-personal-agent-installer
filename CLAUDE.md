# Hermes Personal Agent Installer — contributor notes

A one-command **Bash** installer that stands up one personal [Hermes](https://github.com/NousResearch/hermes-agent)
agent on a VPS the operator owns.

## Layout
- `install.sh` — entry point. `--steps <csv>` runs slices in order; `--steps all` runs the lot. `--dry-run` previews.
- `lib/*.sh` — **one slice per file**: `base` (de-privileged user + layout), `harden` (UFW/fail2ban/Tailscale),
  `secrets` (1Password CLI + op:// references), `runtime` (Hermes), `config` (config.yaml + SOUL/USER + gateway
  service), `codex` (the primary brain), `openviking` (persistent memory), `persona` (the SOUL/USER interview),
  `backup` (daily GitHub push), `wizard` (the one-command orchestration). Plus `common.sh` helpers.
- `examples/` — the 1Password item layout + an env example.
- `docs/` — the security model + roadmap.
- `scripts/` — the clean-room denylist scanner + its self-test.

## Conventions
- Bash, `set -euo pipefail`. Every action goes through the `run` / `step` / `log` / `warn` / `die` helpers (they're
  dry-run aware). The agent **never runs as root** — only install/maintenance does.
- Slices are **idempotent**, and `--dry-run` must change nothing.
- **Secrets never touch the repo or the disk** — they're referenced as `op://YOUR_VAULT/...` and resolved at
  runtime with `op run`. The only local secret is the read-only 1Password service-account token.
- **Clean-room:** no operator-specific identifiers (host names, IPs, vault names, Slack IDs, private paths) in the
  repo. CI enforces this with a denylist + gitleaks.

## Before a PR
```bash
for f in install.sh lib/*.sh; do bash -n "$f"; done   # syntax
shellcheck install.sh lib/*.sh                         # lint
bash scripts/check-denylist.sh                         # clean-room
npm test                                               # denylist self-test
```
CI additionally installs each slice on a throwaway Ubuntu runner and runs the whole `--steps all` end-to-end.
