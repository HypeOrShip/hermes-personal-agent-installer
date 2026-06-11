#!/usr/bin/env bash
# Slice S2 — base install: dependencies, the de-privileged agent user, and the
# base directory layout. Least privilege: the agent user has NO sudo and a
# locked password. Idempotent: safe to re-run.
#
# Sourced by install.sh after lib/common.sh. Entry point: base_install.

# Base OS packages the agent runtime needs later (Python venv, git, curl, TLS).
# Kept minimal — feature slices add their own deps.
BASE_PACKAGES="python3 python3-venv python3-pip git curl ca-certificates"

# Install base packages via apt (Ubuntu/Debian). No-ops cleanly under --dry-run.
base_install_deps() {
  step "Installing base packages: ${BASE_PACKAGES}"
  if ! have apt-get; then
    if [ "${DRY_RUN:-0}" = "1" ]; then
      warn "apt-get not present here — on the target Ubuntu/Debian VPS this would install: ${BASE_PACKAGES}"
      return 0
    fi
    die "apt-get not found — this installer targets Ubuntu/Debian VPSes."
  fi
  run env DEBIAN_FRONTEND=noninteractive apt-get update -qq
  # shellcheck disable=SC2086  # word-splitting BASE_PACKAGES is intentional
  run env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $BASE_PACKAGES
}

# Create the dedicated, de-privileged agent user.
#   - own login group, home dir created, bash shell
#   - password LOCKED (no password login; this account is service-only)
#   - NO sudo / no wheel/admin group  -> cannot escalate
base_create_user() {
  local user="$1"
  valid_username "$user" || die "invalid agent username: '$user' (use lowercase a-z0-9_-, start with a letter)"
  step "Creating de-privileged agent user: ${user}"
  if user_exists "$user"; then
    log "user '${user}' already exists — leaving it as-is"
  else
    run useradd --create-home --user-group --shell /bin/bash "$user"
    # Lock the password: the agent account is never password-logged-into.
    run passwd --lock "$user"
    log "created '${user}' (locked password, own group, no sudo)"
  fi
  # Defensive: make sure we never accidentally grant escalation.
  if id -nG "$user" 2>/dev/null | tr ' ' '\n' | grep -qxE 'sudo|wheel|admin'; then
    die "agent user '${user}' is in a privileged group — refusing (the agent must not be able to escalate)"
  fi
}

# Create the base directory layout under the agent's home, owned by the agent.
#   ~/.hermes            agent home (config/state live here in later slices)
#   ~/.hermes/secrets    0700 — runtime-materialised secrets (never committed)
#   ~/.config            standard config root
base_create_layout() {
  local user="$1" home
  home="$(user_home "$user")"
  if [ -z "$home" ]; then
    [ "${DRY_RUN:-0}" = "1" ] || die "could not resolve home dir for '${user}'"
    home="/home/${user}"
    warn "home for '${user}' unknown (dry-run) — assuming ${home}"
  fi
  step "Creating base layout under ${home}"
  local d
  for d in "$home/.hermes" "$home/.hermes/secrets" "$home/.config"; do
    run install -d -o "$user" -g "$user" -m 0750 "$d"
  done
  # Secrets dir is stricter: owner-only.
  run chmod 0700 "$home/.hermes/secrets"
  log "layout ready (.hermes, .hermes/secrets [0700], .config)"
}

# Orchestrates the base slice.
base_install() {
  local user="${1:?base_install: agent username required}"
  need_root
  base_install_deps
  base_create_user "$user"
  base_create_layout "$user"
  step "Base install complete for agent user '${user}'."
}
