# Security model & safe defaults

This document records the guardrails the installer is built around. S1
establishes the rails; later slices implement the privileged behavior behind
them.

## Principles

- **Clean-room.** No operator's private scripts, paths, host names, tailnets, or
  identifiers enter this repo. See *clean-room rewrite* in
  [../CONTEXT.md](../CONTEXT.md).
- **Secrets out of the repo.** Secrets live in 1Password (referenced as
  `op://YOUR_VAULT/YOUR_ITEM/field`) or in GitHub Actions secrets — never in
  code, env files, logs, or commit history.
- **Least privilege / two-SA pattern.** Install-time reads and the running agent
  use separate, independently-revocable credentials.
- **Single tenant.** One agent, owned by the operator. No fleet, no provisioning
  of others.
- **Private until scrubbed.** A human *manual security scrub* gates any public
  release; the repo stays private until then.

## What CI enforces

| Check | Tool | Fails on |
| --- | --- | --- |
| Denylist | `scripts/check-denylist.sh` | private script names, privileged paths, secret-shaped tokens, real public IPv4, Slack IDs, tailnet hostnames |
| Secret scan | gitleaks | any detected secret across history |
| Shell lint | shellcheck + `bash -n` | shell errors / unsafe patterns in `.sh` files |
| Compile-gate | `npm run build` / `npm test` | build break; denylist self-test failure |

The denylist patterns live in [`../scripts/denylist.txt`](../scripts/denylist.txt).
Public-IPv4 and Slack-ID detection are handled specially in the scanner because
they need an allowlist / digit filter. Documentation IP placeholders use the
RFC5737 ranges (`192.0.2.x`, `198.51.100.x`, `203.0.113.x`), which the scanner
allows.

## Safe defaults

- Agent runs as a **de-privileged user** (no sudo; install refuses if it could escalate).
- Firewall (UFW) deny-incoming, SSH kept reachable + fail2ban, Tailscale for private access.
- Secrets only ever resolved at runtime via `op run` — never written to disk (only the bootstrap SA token + Codex `auth.json` live locally, 0600).
- Auto-approve is gated to `SLACK_ALLOWED_USERS` (only the operator can trigger the agent).
- Run only on a VPS the operator owns and can rebuild; prove isolation on a throwaway VPS first.

## Pre-public security scrub checklist

The repo is **private** until every box here is checked. Run before flipping it public:

- [ ] `bash scripts/check-denylist.sh` is clean on `main` (no operator identifiers / token shapes).
- [ ] gitleaks is clean across **history**, not just the tip (`gitleaks dir .` + a full-history scan).
- [ ] No real values in `examples/` — only `op://YOUR_VAULT/...`, `xoxb-REPLACE`, `YOUR_*` placeholders.
- [ ] No real hostnames/IPs/tailnet names, Slack channel/member IDs, private repo or vault names anywhere.
- [ ] CI `clean-room` + `secret-scan` green on `main`.
- [ ] README/docs reviewed by a human for anything that leaks the operator's specific setup.
- [ ] Enable **branch protection** on `main` (require PR + green CI) before/at publish.
- [ ] A fresh **throwaway-VPS** run of `--steps all` succeeds for a person who is *not* the author.
