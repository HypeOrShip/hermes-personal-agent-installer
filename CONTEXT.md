# CONTEXT — ubiquitous language

Shared definitions for the Hermes Personal Agent Installer. When these terms
appear in code, docs, PRs, or commit messages, they mean exactly this.

### one-vault, per-platform items

The user-supplied configuration lives in **one 1Password vault**, with **one
API Credential item per platform** — `OpenAI`, `OpenRouter`, `Agent`, `Slack`,
`Tailscale`, `GitHub` (the **standard** item names; matches the operator's own
convention). Single-secret items hold the value in the native **`credential`**
field; multi-field items use named concealed fields:

- `OpenAI` / `OpenRouter` / `Tailscale` → `credential`
- `Agent` → `name`, `allowed_user` (your Slack member ID), `home_channel`
- `Slack` → `bot_token`, `app_token`, `signing_secret`
- `GitHub` → `backup_pat`, `backup_repo`
- `1Password Service Account` → `credential` (the read-only SA token, stored for
  reference/recovery; the box still needs it locally to bootstrap `op`)

**Every field is concealed.** The installer reads each value as
`op://YOUR_VAULT/<Item>/<field>`. The goal: a viewer can see and identify each
service at a glance — not one dumping ground — while the installer resolves
everything from a single vault via a read-only service account.

### two-vault / two-SA pattern

Two vaults, two service accounts — separate least-privilege roles rather than one
do-everything credential:

1. a **READ-ONLY** vault (the per-platform items above) + a **read-only service
   account** the agent uses for everything. Even a fully compromised agent can't
   alter or destroy the vault.
2. a separate **WRITABLE** vault holding only **rotating seed tokens** (e.g. a
   `Slack_AppConfig` item with a single-use `refresh_token`) + a **write-scoped
   service account** that a refresher uses to rotate + write them back.

The agent (and the box) only ever hold the **read-only** token; the writable
token is narrowly scoped to the seeds vault, kept apart, and used solely by the
refresher. Each SA sees exactly one vault. (Rotating OAuth like Codex stays in a
local writable `auth.json`, NOT 1Password — a read-only `op://` would block its
refresh.) For a basic V1 agent the write side is the *architecture*; the
refresher itself is an advanced add-on.

### clean-room rewrite

This repo is written **only** from a public specification. It deliberately does
**not** copy, port, or paraphrase any operator's private on-box provisioning
scripts, hardcoded paths, host names, tailnets, or identifiers. If a string
would only be knowable from someone's private machine, it does not belong here —
and CI's denylist is there to enforce that.

### throwaway VPS isolation proof

Before trusting the installer on a host you care about, run it end-to-end on a
**disposable VPS** and verify the agent is properly isolated (it can only do
what it should, touches only its own user/paths, holds no more privilege than
intended). The throwaway host is destroyed afterward. This is the evidence that
the install is contained before it goes anywhere real.

### manual security scrub

A **human** review that must pass before this repo could ever be made public:
confirm no secrets, no real infrastructure identifiers, and no private
clean-room violations are present. The repo stays **private** until that scrub
explicitly clears it. Automated CI (denylist + secret scan) supports the scrub
but does not replace the human sign-off.
