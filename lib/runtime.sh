#!/usr/bin/env bash
# Slice S5 — Hermes runtime install.
#
# Clones the public upstream Hermes Agent (github.com/NousResearch/hermes-agent,
# MIT), creates a Python venv, and installs it so the `hermes` CLI is available.
# Everything is owned by the AGENT user and runs as that user — the runtime is
# the agent's, not root's. We install upstream as-is; we do not vendor or fork it.
#
# Pin the upstream with HERMES_REF (default: main). Entry point: runtime_install.

HERMES_REPO_URL="https://github.com/NousResearch/hermes-agent.git"

runtime_install_hermes() {
  local user="$1"
  local ref="${HERMES_REF:-main}"
  local home; home="$(user_home "$user")"
  if [ -z "$home" ]; then
    [ "${DRY_RUN:-0}" = "1" ] || die "could not resolve home dir for '${user}'"
    home="/home/${user}"
  fi
  local dir="$home/.local/share/hermes-agent"
  local venv="$home/.local/share/hermes-venv"
  step "Installing Hermes runtime (upstream ref=${ref}) for '${user}'"
  apt_install python3 python3-venv python3-pip python3-dev build-essential git ca-certificates
  if [ "${DRY_RUN:-0}" = "1" ]; then
    warn "would clone ${HERMES_REPO_URL}@${ref} -> ${dir}; create venv ${venv}; pip install (as ${user})"
    return 0
  fi
  # Clone/update + checkout the pinned ref, as the agent user (-H => its HOME).
  run sudo -H -u "$user" mkdir -p "$home/.local/share"
  if sudo -u "$user" test -d "$dir/.git"; then
    run sudo -H -u "$user" git -C "$dir" fetch -q origin
  else
    run sudo -H -u "$user" git clone -q "$HERMES_REPO_URL" "$dir"
  fi
  run sudo -H -u "$user" git -C "$dir" checkout -q "$ref"
  # Fresh venv + install the cloned package.
  run sudo -H -u "$user" python3 -m venv "$venv"
  run sudo -H -u "$user" "$venv/bin/pip" install -q --upgrade pip
  run sudo -H -u "$user" "$venv/bin/pip" install -q "$dir"
  log "hermes runtime installed in ${venv}"
}

runtime_install() {
  local user="${1:?runtime_install: agent user required}"
  need_root
  runtime_install_hermes "$user"
  step "Hermes runtime ready (the agent's venv provides the 'hermes' CLI)."
}
