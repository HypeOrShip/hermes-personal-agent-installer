# Setup Checklist — your personal Hermes agent

Tick these off top-to-bottom. **The order matters:** get your tools ready, fill 1Password as you collect each
secret (exact field names!), *then* run the install — so it flows start to finish with no mid-run stops.

> Copy this into a GitHub issue, a note, or print it — the `- [ ]` boxes are tickable.

---

## Phase 1 — Your tools (on your computer)
Set these up first so the rest goes cleanly.

- [ ] **Codex CLI** — install + log in: `curl -fsSL https://chatgpt.com/codex/install.sh | sh` → run `codex` → sign in.
      *(Optional helper for the box-side install. Separate from the agent's own Codex brain, which logs in later, on the server.)*
- [ ] **1Password CLI (`op`)** — install (`brew install 1password-cli`) + sign in.
      - [ ] `op signin` (or `eval $(op signin)`)
      - [ ] `op vault list` (confirm vault access)
- [ ] **Open the 1Password app** and create your **empty item shells now** (exact field names below) — so you
      just paste each value in as you collect it.

Handy tabs to open now (you'll fill these across Phases 2–4):
- 1Password service accounts — https://my.1password.com/developer-tools/infrastructure-secrets/serviceaccount
- OpenAI API keys — https://platform.openai.com/api-keys
- OpenRouter keys — https://openrouter.ai/keys
- GitHub fine-grained PAT — https://github.com/settings/personal-access-tokens
- *(optional)* Tailscale auth keys — https://login.tailscale.com/admin/settings/keys
- A VPS from any provider (fresh Ubuntu 22.04/24.04, root/sudo) — e.g. Hostinger, Hetzner, DigitalOcean

### The 1Password items (create the shells — names + fields must match EXACTLY)
One vault (any name, e.g. `Hermes`) readable by your **read-only** service account. One **API Credential** item
per platform, **all fields concealed**:

| Item | Fields |
|---|---|
| **OpenAI** | `credential` |
| **OpenRouter** | `credential` |
| **Slack** | `bot_token`, `app_token`, `signing_secret`, `allowed_user`, `home_channel` |
| **GitHub** | `backup_pat`, `backup_repo` |
| **Tailscale** | `credential` *(optional)* |

*(No "agent name" field — you name your agent by talking to it in Slack after install. Its Slack **display** name
comes from the app manifest in Phase 3.)*

---

## Phase 2 — APIs (collect each key, paste straight into 1Password)
- [ ] **OpenAI** key → `OpenAI/credential` &nbsp;**⚠️ REQUIRED** (powers memory + voice)
- [ ] **OpenRouter** key → `OpenRouter/credential` (the model fallback)
- [ ] **GitHub** — create a private backup repo + a fine-scoped PAT → `GitHub/backup_pat` + `backup_repo` (`you/your-repo`)
- [ ] *(optional)* **Tailscale** auth key → `Tailscale/credential` (private access to the box)

---

## Phase 3 — Slack
- [ ] Create the app → https://api.slack.com/apps → **From an app manifest** → paste
      [`slack-app-manifest.json`](slack-app-manifest.json) → Create.
      *(Want a custom bot name/icon? Edit `display_information.name` + `bot_user.display_name` in the manifest
      first, or rename later in the app's **Basic Information**.)*
- [ ] Install to Workspace → Allow → **Bot token** (`xoxb-…`) → `Slack/bot_token`
- [ ] **App-Level Token** (`connections:write`) → `Slack/app_token`
- [ ] **Signing Secret** → `Slack/signing_secret`
- [ ] Your **member ID** (`U…`) → `Slack/allowed_user` *(only you can talk to the agent)*
- [ ] A **channel ID** (`C…`) for the agent's home → `Slack/home_channel`

---

## Phase 4 — Finish 1Password (the service account)
- [ ] **Read-only service account** — scoped to your vault (**read-only**) → copy its token (`ops_…`).
      This is your `OP_SERVICE_ACCOUNT_TOKEN`; the vault name is `OP_VAULT`. **This is the only secret the agent ever holds.**
- [ ] *(optional, advanced)* A separate **write-scoped** SA on its own vault, for future token rotation — not used
      by the V1 installer. Skip it unless you know you want it. See [CONTEXT.md](../CONTEXT.md).

---

## Phase 5 — The host (one command)
- [ ] *(only if you've SSH'd to this IP before — e.g. a re-imaged box)* clear the stale host key:
      `ssh-keygen -R <your-ip>`
- [ ] `ssh root@<your-ip>`
- [ ] `git clone https://github.com/HypeOrShip/hermes-personal-agent-installer.git && cd hermes-personal-agent-installer`
- [ ] **Dry run** (changes nothing — preview the whole thing):
      `sudo env OP_SERVICE_ACCOUNT_TOKEN='ops_…' OP_VAULT='Hermes' bash install.sh --steps all --dry-run`
- [ ] **Real run** — same command, without `--dry-run`
- [ ] **Codex login** when prompted (the agent's brain) — open `auth.openai.com/codex/device`, enter the code (~30s)
- [ ] **Onboard in Slack** — post in the agent's channel. Its **first job** is to interview you (who you are,
      what you want, who it should be), then it writes its own `SOUL.md`/`USER.md`, hands you an avatar prompt,
      and tells you how to set its Slack name/icon. No file editing on the box.
- [ ] **Verify** — it replies in Slack; `systemctl status hermes-agent openviking` shows both running.

---

## Notes
- **Exact field names matter** — the installer verifies every reference up front and stops, naming the wrong
  field, if you mislabel one. Filling them carefully in Phases 1–4 is *why* the install just flows.
- **Two Codex logins** — the optional local CLI (Phase 1, your helper) and the agent's own brain (Phase 5, on the box).
- **Nothing plain on the box** — secrets live in 1Password as `op://` references, resolved at runtime with `op run`.
- **Use at your own risk** — this stands up a real internet-facing server; review what it does first (it's all readable Bash).
