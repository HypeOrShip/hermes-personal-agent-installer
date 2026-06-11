#!/usr/bin/env bash
# Slice S8 — backups: a daily push of the agent's EDITABLE config to a private
# GitHub repo, with a secret-scrub so nothing sensitive ever leaves the box.
#
# Backs up: SOUL.md, USER.md, config.yaml.
# NEVER backs up: op-secrets.env, auth.json (Codex token), /etc/hermes-agent
# (the SA token), or any resolved secret. A scrub aborts the push if a
# secret-shaped string is ever found.
#
# Uses GITHUB_BACKUP_REPO (owner/name) + GITHUB_BACKUP_PAT, resolved at runtime
# from the GitHub 1P item via `op run`. Entry: backup_install.

# Write the backup script the timer runs (under op run, so GITHUB_* resolve).
backup_write_script() {
  local user="$1" home="$2"
  local script="$home/.hermes/scripts/hermes-backup"
  run install -d -o "$user" -g "$user" -m 0750 "$home/.hermes/scripts"
  if [ "${DRY_RUN:-0}" = "1" ]; then warn "would write ${script}"; return 0; fi
  cat > "$script" <<'SCRIPT'
#!/usr/bin/env bash
# Daily config backup -> private GitHub repo. Secrets are NEVER included.
# Invoked under: op run --env-file ~/.hermes/op-secrets.env -- hermes-backup
set -euo pipefail
HD="${HERMES_HOME:-$HOME/.hermes}"
REPO="${GITHUB_BACKUP_REPO:-}"; PAT="${GITHUB_BACKUP_PAT:-}"
if [ -z "$REPO" ] || [ -z "$PAT" ]; then echo "backup: GITHUB_BACKUP_REPO/PAT not set — skipping"; exit 0; fi
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
git clone -q "https://x-access-token:${PAT}@github.com/${REPO}.git" "$work" 2>/dev/null || git -C "$work" init -q
# Copy ONLY the editable config — never secrets.
for f in SOUL.md USER.md config.yaml; do [ -f "$HD/$f" ] && cp "$HD/$f" "$work/$f"; done
# Secret scrub: refuse to push if anything looks like a real secret.
if grep -rIlE 'xox[baprs]-[A-Za-z0-9-]{10,}|sk-(or-v1|proj)-[A-Za-z0-9_-]{12,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|ops_eyJ' "$work" --exclude-dir=.git 2>/dev/null; then
  echo "backup: ABORT — a secret-shaped string was found; not pushing"; exit 1
fi
cd "$work"; git add -A
if git -c user.email=agent@localhost -c user.name=hermes-agent commit -q -m "config backup $(date -u +%FT%TZ 2>/dev/null || echo now)" 2>/dev/null; then
  git push -q "https://x-access-token:${PAT}@github.com/${REPO}.git" HEAD:main 2>/dev/null && echo "backup: pushed"
else
  echo "backup: nothing changed"
fi
SCRIPT
  run chmod 0750 "$script"; run chown "$user:$user" "$script"
  log "wrote ${script}"
}

# Install a daily systemd timer that runs the backup under op run as the agent.
backup_install_timer() {
  local user="$1" home="$2"
  step "Installing the daily backup timer (hermes-backup.timer)"
  if [ "${DRY_RUN:-0}" = "1" ]; then warn "would write hermes-backup.service + .timer"; return 0; fi
  cat > /etc/systemd/system/hermes-backup.service <<UNIT
[Unit]
Description=Hermes agent config backup (to private GitHub)
After=network-online.target

[Service]
Type=oneshot
User=${user}
Environment=HERMES_HOME=${home}/.hermes
# Optional (-): if the SA token file isn't present yet, the backup script's own
# guard skips cleanly instead of the unit hard-failing.
EnvironmentFile=-/etc/hermes-agent/op.env
ExecStart=/usr/local/bin/op run --env-file ${home}/.hermes/op-secrets.env -- ${home}/.hermes/scripts/hermes-backup
UNIT
  cat > /etc/systemd/system/hermes-backup.timer <<'UNIT'
[Unit]
Description=Daily Hermes agent config backup

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
UNIT
  log "wrote hermes-backup.service + .timer"
  run systemctl daemon-reload
  if [ "${APPLY_NETWORK:-1}" = "1" ]; then
    run systemctl enable --now hermes-backup.timer
    log "hermes-backup.timer enabled (daily 03:00)"
  else
    warn "APPLY_NETWORK=0 — timer installed but NOT enabled"
  fi
}

backup_install() {
  local user="${1:?backup_install: agent user required}"
  need_root
  local home; home="$(user_home "$user")"
  if [ -z "$home" ]; then
    [ "${DRY_RUN:-0}" = "1" ] || die "could not resolve home dir for '${user}'"
    home="/home/${user}"
  fi
  backup_write_script "$user" "$home"
  backup_install_timer "$user" "$home"
  step "Backups configured — daily config push to GitHub (secrets scrubbed)."
}
