#!/usr/bin/env bash
# Hermes Personal Agent Installer — entry point.
#
# Sets up ONE personal Hermes agent on your own VPS. Run as root (sudo); the
# installer creates a de-privileged agent user — the AGENT itself never runs as
# root. Root is only used at install/maintenance time.
#
# Usage:
#   sudo ./install.sh [--user <name>] [--steps <csv>] [--dry-run] [--help]
#
#   --user <name>   Agent user to create/use (default: hermes). lowercase a-z0-9_-
#   --steps <csv>   Which steps to run. `all` = the whole install in order (the
#                   one command). Default: base. Available: all, base, harden,
#                   secrets, runtime, config, codex, backup
#   --dry-run       Print what would happen; change nothing.
#   --help          This help.
#
# Env:
#   APPLY_NETWORK=0    Stage hardening + install the gateway service WITHOUT
#                      flipping switches / starting it. Default 1.
#   TAILSCALE_AUTHKEY  If set, `harden` joins your tailnet automatically.
#   OP_SERVICE_ACCOUNT_TOKEN / OP_VAULT
#                      Read-only 1Password SA token + the vault holding the
#                      per-platform items (OpenAI, OpenRouter, Agent, Slack, …).
#   HERMES_REF         Upstream Hermes Agent ref to install (default: main).
#   HERMES_MODEL       Default model for config (default: openai/gpt-4o-mini).
#   CODEX_MODEL        Codex model once logged in (default: gpt-5.5).
#   CODEX_SKIP_LOGIN=1 Skip the interactive Codex login (config only).
#
# Slices: base (user/layout/deps), harden (firewall/fail2ban/tailscale),
#         secrets (1Password CLI + per-platform refs), runtime (Hermes install),
#         config (config.yaml + SOUL/USER + gateway service),
#         codex (interactive Codex login -> primary brain),
#         backup (daily config push to GitHub, secrets scrubbed).
#         all = run every step in order (the one command).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$HERE/lib/common.sh"
# shellcheck source=lib/base.sh
. "$HERE/lib/base.sh"
# shellcheck source=lib/harden.sh
. "$HERE/lib/harden.sh"
# shellcheck source=lib/secrets.sh
. "$HERE/lib/secrets.sh"
# shellcheck source=lib/runtime.sh
. "$HERE/lib/runtime.sh"
# shellcheck source=lib/config.sh
. "$HERE/lib/config.sh"
# shellcheck source=lib/codex.sh
. "$HERE/lib/codex.sh"
# shellcheck source=lib/backup.sh
. "$HERE/lib/backup.sh"
# shellcheck source=lib/openviking.sh
. "$HERE/lib/openviking.sh"
# shellcheck source=lib/persona.sh
. "$HERE/lib/persona.sh"
# shellcheck source=lib/wizard.sh
. "$HERE/lib/wizard.sh"

AGENT_USER="hermes"
STEPS="base"
export DRY_RUN="${DRY_RUN:-0}"
export APPLY_NETWORK="${APPLY_NETWORK:-1}"

usage() { sed -n '2,35p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --user)    AGENT_USER="${2:?--user needs a value}"; shift 2 ;;
    --steps)   STEPS="${2:?--steps needs a value}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

run_step() {
  case "$1" in
    base)    base_install "$AGENT_USER" ;;
    harden)  harden_install ;;
    secrets) secrets_install "$AGENT_USER" ;;
    runtime) runtime_install "$AGENT_USER" ;;
    config)  config_install "$AGENT_USER" ;;
    codex)   codex_install "$AGENT_USER" ;;
    openviking) openviking_install "$AGENT_USER" ;;
    persona) persona_install "$AGENT_USER" ;;
    backup)  backup_install "$AGENT_USER" ;;
    all)     wizard_all "$AGENT_USER" ;;
    *)       die "unknown step: '$1' (available: all, base, harden, secrets, runtime, config, codex, openviking, persona, backup)" ;;
  esac
}

step "Hermes Personal Agent Installer  (user=${AGENT_USER}  steps=${STEPS}  dry-run=${DRY_RUN})"
IFS=',' read -ra _steps <<< "$STEPS"
for s in "${_steps[@]}"; do
  run_step "$(printf '%s' "$s" | tr -d '[:space:]')"
done
step "Done."
