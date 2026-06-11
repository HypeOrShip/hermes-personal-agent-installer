#!/usr/bin/env bash
# Slice S9 — first-run wizard: the one-command install.
#
# `install.sh --steps all` runs the whole sequence in order, with a preflight and
# a friendly summary. This is the "one command" experience. Entry: wizard_all.

# secrets BEFORE harden: harden's Tailscale step resolves its auth key from 1Password,
# which needs `op` installed (the secrets step does that).
WIZARD_STEPS=(base secrets harden runtime config codex openviking backup)

wizard_preflight() {
  step "Preflight"
  if [ "${DRY_RUN:-0}" != "1" ] && [ "$(id -u)" -ne 0 ]; then
    die "run with sudo — the installer needs root to create the user + install packages (the agent itself never runs as root)."
  fi
  [ -n "${OP_VAULT:-}" ] || warn "OP_VAULT not set — the secrets/config steps need your 1Password vault name."
  [ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ] || warn "OP_SERVICE_ACCOUNT_TOKEN not set — the agent can't resolve secrets without the read-only SA token."
  log "preflight done"
}

wizard_summary() {
  local user="$1"
  step "Install complete 🎉"
  {
    printf '  Your Hermes agent is set up:\n'
    printf "    - runs as the de-privileged user '%s', as a systemd service (hermes-agent)\n" "$user"
    printf '    - talks to you on Slack — free-response in its home channel\n'
    printf '    - Codex primary brain, OpenRouter fallback\n'
    printf '    - daily config backup to GitHub (secrets scrubbed)\n'
    printf '  Next:\n'
    printf '    - say hi in your agent'"'"'s Slack channel — its first job is to interview you\n'
    printf "      and write its own SOUL.md ('who you are') + USER.md ('who I am'). Edit them anytime.\n"
    printf '    - check it:  systemctl status hermes-agent   ·   logs:  journalctl -u hermes-agent -f\n'
  } >&2
}

wizard_all() {
  local user="${1:?wizard_all: agent user required}"
  wizard_preflight
  local s
  for s in "${WIZARD_STEPS[@]}"; do
    run_step "$s"
  done
  wizard_summary "$user"
}
