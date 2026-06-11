# Hermes Personal Agent Installer

> **One command stands up a personal AI agent on your own VPS** — a de-privileged
> agent, a hardened box, Slack chat, a Codex brain (OpenRouter fallback), persistent
> OpenViking memory, and a daily backup. Secrets stay in **1Password** and are
> resolved at runtime (`op run`) — nothing sensitive ever lands on disk.
>
> ```bash
> sudo ./install.sh --steps all            # the whole thing
> sudo ./install.sh --steps all --dry-run  # preview — changes nothing
> ```
>
> Every step is verified on a fresh Ubuntu runner in CI, and the full chain has been
> proven on a real VPS (agent up, de-privileged, replying on Slack via Codex).

📺 **Watch the build, step by step:** [Hype or Ship on YouTube](https://www.youtube.com/@HypeorShip) &nbsp;·&nbsp;
🌐 **Guides + the easy-start pack:** [HypeorShip.com](https://HypeorShip.com/Tutorials/base-Hermes)

It sets up **one** personal [Hermes](https://github.com/NousResearch/hermes-agent)
agent that **you** own and run — single-tenant, Slack-first. This is a **clean-room**
project: written from public specifications, with no operator-specific scripts, paths,
host names, or identifiers.

## What you get

After one run, your VPS is running an agent that:

- runs as a **de-privileged user** (never root), as a systemd service that survives reboot;
- is reachable on **Slack** — it replies to everything in its own channel, no @mention;
- thinks with **Codex** (your ChatGPT oAuth login) and falls back to **OpenRouter**;
- has **persistent memory** (OpenViking) — it remembers across sessions, with backup `.md` notes you can sync to Obsidian (a future video);
- knows **who it is** (`SOUL.md`) and **who you are** (`USER.md`), set via a short interview;
- backs its config up daily to a private GitHub repo (secrets scrubbed);
- sits behind a **firewall + fail2ban**, with **Tailscale** ready for private access.

## Prerequisites

You bring the accounts; the installer wires them together.

| You need | For |
|---|---|
| A **VPS you own** (fresh Ubuntu, root/sudo)  | the agent's always-on home |
| **1Password** (paid — service accounts) | where every secret lives |
| A **ChatGPT / Codex** subscription | the primary brain (interactive login) |
| An **OpenAI** API key | memory (OpenViking) + voice — **required** |
| An **OpenRouter** API key | the model fallback |
| A **Slack** workspace you control | where you talk to the agent |
| **GitHub** (a private repo + a fine-scoped PAT) | the daily config backup |
| **Tailscale** (optional) | private access to the box |

## Setup (the whole surface)

1. **Create the Slack app** — paste [`examples/slack-app-manifest.json`](examples/slack-app-manifest.json)
   into *Create New App → From a manifest*, install it, and copy the bot/app tokens + signing secret.
2. **Fill your 1Password items** — one **API Credential** item per platform, following
   [`examples/1password-item.example.md`](examples/1password-item.example.md) (every field concealed makes sure you follow the names EXACTLY).
   Create a **read-only service account** scoped to that vault.
3. **Run the one command** on the VPS:
   ```bash
   git clone https://github.com/HypeOrShip/hermes-personal-agent-installer.git
   cd hermes-personal-agent-installer
   sudo env OP_SERVICE_ACCOUNT_TOKEN='ops_…' OP_VAULT='YourVault' bash install.sh --steps all
   ```
4. **Complete the Codex login** when prompted (a ~30-second device-code flow).
5. **Answer the persona interview** — name your agent, describe yourself; it writes `SOUL.md`/`USER.md` and hands you a ready-to-paste avatar prompt.

Then post in your agent's Slack channel — it replies. That's it.

## What the installer does 

`--steps all` runs these in order (you can also run any one with `--steps <name>`):

| Stages| What it does |
|---|---|
| `base` | creates the de-privileged agent user + the `~/.hermes` layout |
| `secrets` | installs the 1Password CLI, renders `op://` references, **verifies every field up front in case you labelled incorrectly** |
| `harden` | UFW firewall + fail2ban + Tailscale (auth key from 1Password) |
| `runtime` | clones upstream Hermes (MIT) into an agent-owned venv |
| `config` | writes `config.yaml` + starter `SOUL`/`USER` + the gateway systemd service |
| `codex` | the interactive Codex login → Codex-primary, OpenRouter fallback |
| `openviking` | the memory server + wiring (built-in notes + the OpenViking provider) |
| `persona` | the SOUL/USER interview + the Codex avatar prompt |
| `backup` | a daily timer that pushes the editable config to GitHub (secrets scrubbed) |

## Security model

- The **agent never runs as root** — the installer creates a locked-down user and refuses to grant it escalation.
- **Secrets never touch the repo or disk.** They're stored in 1Password and resolved at runtime with `op run --env-file op-secrets.env -- …`; the only local secret is the read-only service-account token.
- **Two service accounts:** a read-only one the agent uses, and (optionally) a write-scoped one for rotating tokens — kept apart. See [CONTEXT.md](CONTEXT.md).
- **Clean-room + CI:** a denylist scanner + gitleaks fail the build on any operator identifier or secret shape.

Run it only on a VPS or server you own and can rebuild

## CI

Every PR + push to `main` runs: the **denylist** scan, **gitleaks** over full history, **shellcheck**, and a job that **installs each stage on a throwaway Ubuntu runner** (including the full `--steps all` end-to-end).

```bash
bash scripts/check-denylist.sh   # clean-room scan
npm test                         # the denylist self-test
shellcheck install.sh lib/*.sh   # lint
```

## ⚠️ Use at your own risk — no warranty, no liability

This is shared in the spirit of *"here's how I set things up"* — **not** as a guaranteed, audited product.
By using it you accept that:

- It's provided **as-is, with absolutely no warranty**, and the author takes **no responsibility and no
  liability** for anything that happens as a result — data loss, downtime, security issues, surprise bills,
  or anything else.
- **You are responsible for your own setup.** Read the code, understand what each step does, and make your
  own decision before you run it. I'm no security expert — **check the work yourself.**
- Run it only on a **VPS/server you own and can rebuild**, with **throwaway credentials you can rotate**,
  and **entirely at your own risk**.

If that's not for you, that's completely fair — don't run it.

## Credits

Built on [Hermes Agent](https://github.com/NousResearch/hermes-agent) (MIT) and
[OpenViking](https://openviking.ai).
Licensed under the [MIT License](LICENSE) (which also disclaims warranty + liability).
