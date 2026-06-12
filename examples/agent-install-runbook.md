# Let an agent install your agent

Prefer not to run the box-side commands yourself? Hand this runbook to a terminal-capable AI agent
(**Codex**, **Claude Code**, or similar running on your own machine) and it drives the install for you — SSHing in,
cloning, running the installer, and pausing for the handful of things only a human can do.

> You still do the account/secret setup first (Phases 1–4 of [`SETUP-CHECKLIST.md`](SETUP-CHECKLIST.md)). The agent
> only handles the **box-side install** (Phase 5).

## The split
- **Your agent does** (it runs commands): SSH to your VPS → clone the installer → run it → stream the output →
  catch errors → report. It babysits the whole install.
- **You do** (browser / OAuth / secret entry — no agent can): create the Slack app, fill the 1Password items, the
  **Codex device login** on the box, and the **Slack onboarding** afterward. The agent pauses and asks you at each.

## Before you start (≈10 min, you)
1. **Slack app** created (paste the manifest) + bot/app tokens + signing secret copied; your member ID + a channel ID.
2. **1Password items** filled (exact field names) + a **read-only service account** → its token (`ops_…`) + the vault name.
3. Have ready the only box access the agent needs: the **server IP + root password**, plus your
   **`OP_SERVICE_ACCOUNT_TOKEN`** and **`OP_VAULT`**.

## The prompt to paste into your agent

> You're going to install a personal Hermes agent on my VPS for me. Run the commands, show me the output, and
> **pause for me at the human-only moments** — confirm each step before the next. **Never print my tokens.**
>
> 1. SSH to `root@<MY_IP>` — root password: `<MY_ROOT_PASSWORD>`.
> 2. `git clone https://github.com/HypeOrShip/hermes-personal-agent-installer.git && cd hermes-personal-agent-installer`
> 3. **Dry run** (changes nothing) and show me the output:
>    `sudo env OP_SERVICE_ACCOUNT_TOKEN='<MY_TOKEN>' OP_VAULT='<MY_VAULT>' bash install.sh --steps all --dry-run`
> 4. If it's clean, the **real run** (same command, drop `--dry-run`). Stream the output as it goes.
> 5. When it reaches the **Codex device login**, PAUSE — give me the `auth.openai.com/codex/device` URL + code so I
>    authorize it, then continue.
> 6. If you see `✗ MISSING/UNREADABLE: X -> op://…`, STOP and tell me exactly which 1Password field to fix; I'll fix
>    it and you re-run.
> 7. When it finishes, tell me to **post in my agent's Slack channel** — its first job is to interview me and write
>    its own SOUL/USER, so I onboard it there. Then run `systemctl status hermes-agent openviking` to show me both are up.
> 8. **Don't change my server password yourself.** When you're done, just **remind me** to rotate the root password
>    (or switch to SSH keys) and save the new one in 1Password — never ask me for it or write it to any file.

## Notes
- **Run with command approval visible**, not full-auto, so you see what it runs on your box.
- The agent only needs the **read-only** SA token to install — low risk, but tell it not to echo it.
- **Password hygiene:** the root password you give the agent passes through your chat, so treat it as burned —
  rotate it (or move to SSH keys) once setup is done. Keep the new one **only in 1Password**, never in a file or chat.
  (Same principle the installer uses: `op://` references, resolved at runtime — nothing plain on the box.)
- If the agent can't SSH, double-check the IP + root password and that the box has finished booting.
