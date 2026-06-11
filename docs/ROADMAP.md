# Roadmap (slices)

Work lands in small vertical slices. Each slice is PR-only and must keep CI
green. Scope below is indicative and may be refined as slices are picked up.

- **S1 — skeleton + CI safety rails (this slice).** Repo structure, README,
  CONTEXT, placeholder/example files, denylist + secret-scan + shell-lint CI.
  No privileged install behavior.
- **S2 — base install / user creation (done).** `install.sh` + `lib/` create the
  de-privileged agent user (locked password, own group, **no sudo**), the base
  layout (`~/.hermes`, `~/.hermes/secrets` at 0700, `~/.config`), and install base
  packages. `--dry-run` previews without root. CI runs the base install on a
  throwaway Ubuntu runner and asserts user + layout + least privilege + idempotency.
- **S3 — host hardening (done).** `lib/harden.sh`: UFW (deny-incoming/allow-out,
  SSH kept reachable), fail2ban SSH brute-force jail, Tailscale install (+ joins
  the tailnet when `TAILSCALE_AUTHKEY` is set). No-lockout posture: SSH stays
  reachable and SSH auth is left untouched. Irreversible switches (`ufw enable`,
  `tailscale up`, fail2ban restart) gate behind `APPLY_NETWORK=1`; CI stages with
  `APPLY_NETWORK=0` and asserts tools + config validity without cutting the runner.
- **S4 — 1Password wiring (done).** `lib/secrets.sh`: installs the 1Password CLI
  (`op`), renders the agent's runtime env-file as **op:// references only** (no
  real secrets on disk) across **one API Credential item per platform** (OpenAI, OpenRouter,
  Agent, Slack, Tailscale, GitHub — the standard names, all fields concealed), and
  verifies the **read-only service account** can read the vault (skips if
  `OP_SERVICE_ACCOUNT_TOKEN` is unset). Operator supplies `OP_SERVICE_ACCOUNT_TOKEN`
  / `OP_VAULT` out of band. CI installs op + renders refs on a throwaway runner and
  asserts 0600 + references-only.
- **S5 — Hermes runtime (done).** Clones upstream `NousResearch/hermes-agent`
  (MIT), builds an agent-owned Python venv, and installs it (the `hermes` CLI).
  Pin with `HERMES_REF` (default main). CI clones + venvs + pip-installs on a
  throwaway runner and asserts the `hermes` CLI + `hermes_cli` import.
- **S6 — agent config (done).** `lib/config.sh`: writes `config.yaml` (model via
  OpenRouter, auto-approve, **free-response in the agent's home channel** — replies
  to everything posted there, no @mention), starter **SOUL.md** ("who you are") +
  **USER.md** ("who I am"), and installs the gateway as a persistent **systemd
  service** (`hermes-agent.service`, runs under `op run` as the agent user; SA
  token persists to `/etc/hermes-agent/op.env` 0600). `APPLY_NETWORK=0` stages
  without starting. CI asserts the files + unit on a throwaway runner.
- **S7 — Codex login (done).** `lib/codex.sh`: the **interactive** Codex
  device-code login (`hermes auth add openai-codex --type oauth --no-browser`), then
  rewrites `config.yaml` to **Codex-primary with OpenRouter fallback**
  (`CODEX_MODEL`, default gpt-5.5) and restarts the gateway. `CODEX_SKIP_LOGIN=1`
  skips the login (config-only). Single-use-refresh-token caveat documented. CI
  tests the config rewrite (login is interactive, can't be CI'd).
- **S8 — backups (done).** `lib/backup.sh`: a daily systemd timer pushes the
  agent's **editable config** (SOUL.md, USER.md, config.yaml) to a private GitHub
  repo (`GITHUB_BACKUP_REPO`/`GITHUB_BACKUP_PAT`, resolved via `op run`), with a
  **secret-scrub** that aborts if anything secret-shaped is found. NEVER backs up
  op-secrets.env / auth.json / the SA token. CI asserts the units + that the
  scrub aborts on a planted token.
- **S9 — first-run wizard (done).** `lib/wizard.sh`: `install.sh --steps all`
  runs the whole sequence in order (preflight → base → harden → secrets → runtime
  → config → codex → backup) with a friendly summary. **The one command.**
- **S10 — end-to-end proof (done).** CI's `install-e2e-test` runs the full
  `--steps all` install on a fresh Ubuntu runner (staged) and asserts every
  component + the de-privileged agent. The throwaway-VPS isolation proof, in CI —
  **and proven for real:** the full chain stood up a live agent on an actual VPS
  (Slack-connected, Codex brain). Public release still gates on the manual
  security scrub (below).

Nothing here ships until the **manual security scrub** clears the repo for any
public release. See [SECURITY.md](SECURITY.md) and [../CONTEXT.md](../CONTEXT.md).
