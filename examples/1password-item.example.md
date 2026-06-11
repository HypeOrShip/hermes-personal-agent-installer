# Example 1Password items — the STANDARD per-platform layout

The installer reads its secrets from **one 1Password vault** containing **one
API Credential item per platform** (see *one-vault, per-platform items* in
[../CONTEXT.md](../CONTEXT.md)). One item per service so you can see and identify
each at a glance. **Item + field names are the standard** — the installer
references exactly these. **Values are yours** and never go in this repo.

> ⚠️ Placeholders only. Do not paste real tokens, keys, IDs, host names, or IPs
> into this repo — CI will reject them.

## Vault

- **Vault:** `YOUR_VAULT` — any vault your **read-only** service account can read (`OP_VAULT`).
- Create the **API Credential** items below inside it. **Every field is a concealed
  field** so nothing is visible if the vault is ever compromised.

## The items (API Credential type) + their fields

| Item (API Credential)         | Field(s)                                    | Reference                                  |
| ----------------------------- | ------------------------------------------- | ------------------------------------------ |
| **OpenAI**                    | `credential`                                | `op://YOUR_VAULT/OpenAI/credential`        |
| **OpenRouter**                | `credential`                                | `op://YOUR_VAULT/OpenRouter/credential`    |
| **Agent**                     | `name`                                      | `op://YOUR_VAULT/Agent/name`               |
| **Slack**                     | `bot_token`, `app_token`, `signing_secret`, `allowed_user`, `home_channel` | `op://YOUR_VAULT/Slack/bot_token` … |
| **Tailscale**                 | `credential` (optional)                     | `op://YOUR_VAULT/Tailscale/credential`     |
| **GitHub**                    | `backup_pat`, `backup_repo` (recommended)   | `op://YOUR_VAULT/GitHub/backup_pat`        |
| **1Password Service Account** | `credential` (the read-only SA token)       | reference/recovery only                    |

- Single-secret items (OpenAI, OpenRouter, Tailscale) use the **native `credential` field**.
- **Agent** holds just the agent's `name`. **Slack** holds *everything Slack* — the three tokens plus your `allowed_user` (Slack member ID — only you can talk to it) and the agent's `home_channel`.
- ⚠️ **Field names must match EXACTLY** — the installer verifies every reference up front and fails fast (naming the wrong field) rather than breaking halfway through.
- **OpenAI** `credential` powers **memory (OpenViking) — required** + voice; **OpenRouter** is the model fallback.
- **Codex** is the primary brain but logs in **interactively** at install time — **not** a field here.

## Checklist before running the installer

- [ ] Vault readable by your **read-only** 1Password service account (`OP_VAULT`).
- [ ] The API Credential items above exist with the standard names + fields, values filled, **fields concealed**.
- [ ] You can complete the **interactive Codex login** when prompted.
- [ ] You're targeting a VPS you **own and can rebuild**.
