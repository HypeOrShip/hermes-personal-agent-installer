#!/usr/bin/env bash
# Slice S3 — host hardening: firewall (UFW), brute-force protection (fail2ban),
# and private networking (Tailscale).
#
# Safe-by-default, no-lockout posture:
#   - SSH stays REACHABLE (we never tailnet-lock or disable password auth — that
#     would risk locking you out of your own VPS). fail2ban guards brute-force.
#   - We do NOT modify sshd auth settings; the operator's existing SSH access is
#     left exactly as-is.
#   - The irreversible "flip the switch" actions — `ufw enable`, `tailscale up`,
#     restarting fail2ban — are gated behind APPLY_NETWORK=1 (default). Set
#     APPLY_NETWORK=0 to install + stage rules + validate configs WITHOUT
#     activating them (used by CI and cautious operators who want to review first).
#
# Sourced by install.sh after lib/common.sh. Entry point: harden_install.

# Firewall: default-deny inbound, allow outbound, keep SSH (port 22) reachable.
harden_firewall() {
  step "Firewall (UFW): deny incoming, allow outgoing, keep SSH reachable"
  apt_install ufw
  run ufw default deny incoming
  run ufw default allow outgoing
  run ufw allow 22/tcp
  if [ "${APPLY_NETWORK:-1}" = "1" ]; then
    run ufw --force enable
    log "UFW enabled (SSH open; everything else denied inbound)"
  else
    warn "APPLY_NETWORK=0 — UFW rules staged, NOT enabled. Activate with: sudo ufw --force enable"
  fi
}

# Brute-force protection for SSH via fail2ban.
harden_fail2ban() {
  step "Brute-force protection (fail2ban) on SSH"
  apt_install fail2ban
  local jail=/etc/fail2ban/jail.d/hermes-sshd.local
  if [ "${DRY_RUN:-0}" = "1" ]; then
    warn "would write ${jail} (sshd jail: maxretry=5, findtime=10m, bantime=1h)"
  else
    run install -d -m 0755 /etc/fail2ban/jail.d
    cat > "$jail" <<'JAIL'
# Managed by hermes-personal-agent-installer (S3). Brute-force protection for SSH.
[sshd]
enabled  = true
maxretry = 5
findtime = 10m
bantime  = 1h
JAIL
    log "wrote ${jail}"
    have fail2ban-client && run fail2ban-client -t   # validate config
  fi
  if [ "${APPLY_NETWORK:-1}" = "1" ]; then
    run systemctl enable --now fail2ban
    run systemctl restart fail2ban
    log "fail2ban active"
  else
    warn "APPLY_NETWORK=0 — fail2ban config written + validated, service not (re)started"
  fi
}

# Private networking: install Tailscale; join the tailnet only with an auth key.
harden_tailscale() {
  step "Private networking (Tailscale)"
  if have tailscale; then
    log "tailscale already installed"
  elif [ "${DRY_RUN:-0}" = "1" ]; then
    warn "would install Tailscale via https://tailscale.com/install.sh"
  else
    run sh -c 'curl -fsSL https://tailscale.com/install.sh | sh'
  fi
  # Resolve the auth key from 1Password if not passed directly. This is why the
  # wizard runs `secrets` BEFORE `harden` — op is installed + the refs exist by now.
  local authkey="${TAILSCALE_AUTHKEY:-}"
  if [ -z "$authkey" ] && have op && [ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && [ "${DRY_RUN:-0}" != "1" ]; then
    authkey="$(op read "op://${OP_VAULT:-YOUR_VAULT}/Tailscale/credential" 2>/dev/null || true)"
    [ -n "$authkey" ] && log "resolved Tailscale auth key from 1Password"
  fi
  if [ -n "$authkey" ] && [ "${APPLY_NETWORK:-1}" = "1" ]; then
    run tailscale up --authkey "$authkey" --hostname "hermes-${AGENT_USER:-agent}"
    log "joined tailnet as hermes-${AGENT_USER:-agent}"
  else
    warn "not joining tailnet now (no Tailscale auth key in env or 1Password, or APPLY_NETWORK=0). Join later: sudo tailscale up"
  fi
}

# Orchestrates the hardening slice.
harden_install() {
  need_root
  harden_firewall
  harden_fail2ban
  harden_tailscale
  step "Hardening complete — firewall up, fail2ban guarding SSH, Tailscale ready."
}
