# examples/

Reference material you copy from or hand to your agent — nothing here runs on its own.

## Make your agent *yours*
| File | What it's for |
|---|---|
| [`onboarding-interview.md`](onboarding-interview.md) | The questions that turn a generic agent into yours. Your agent asks these in Slack on first contact (its first job) and writes your `USER.md` for you — or paste them into ChatGPT/Codex and draft it yourself. |
| [`SOUL.example.md`](SOUL.example.md) | A fully-developed, opinionated "who you are" persona. Copy it over your `SOUL.md` and change the name/voice, or steal the bits you like. |
| [`USER.example.md`](USER.example.md) | An example filled-in "who I am" so you can see how specific a good one gets. (Fictional person.) |

> Out of the box your agent ships with a deliberately bare `SOUL.md` whose **first job is to onboard you** — message it in Slack and it'll interview you and write `USER.md` itself. These files are for when you'd rather start from a finished persona or draft offline.

## Setup reference (used during install)
| File | What it's for |
|---|---|
| [`SETUP-CHECKLIST.md`](SETUP-CHECKLIST.md) | The whole setup as a tickable checklist, in the right order — tools → 1Password → Slack → install. Start here. |
| `1password-item.example.md` | The exact 1Password item + field names the installer expects. |
| `installer.env.example` | Template for the install-time environment. |
| `slack-app-manifest.json` | Drop-in manifest to create the Slack app. |
