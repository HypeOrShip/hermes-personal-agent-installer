#!/usr/bin/env bash
# Shared helpers for the installer. Sourced by install.sh and lib/*.sh.
# No side effects on source. POSIX-bash, shellcheck-clean.

# --- logging -----------------------------------------------------------------
# All log output goes to stderr so stdout stays clean for any future capture.
log()  { printf '  %s\n'      "$*" >&2; }
step() { printf '\n==> %s\n'  "$*" >&2; }
warn() { printf 'WARN: %s\n'  "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# --- dry-run aware execution -------------------------------------------------
# DRY_RUN=1 prints commands instead of running them. Use `run` for anything that
# mutates the system so --dry-run is a faithful preview.
run() {
  if [ "${DRY_RUN:-0}" = "1" ]; then
    printf 'DRY-RUN: %s\n' "$*" >&2
    return 0
  fi
  "$@"
}

# --- guards ------------------------------------------------------------------
need_root() {
  [ "$(id -u)" -eq 0 ] && return 0
  # Dry-run is a preview — let it run without sudo so users can inspect first.
  if [ "${DRY_RUN:-0}" = "1" ]; then
    warn "not root — dry-run preview only (a real run needs sudo)"
    return 0
  fi
  die "this step needs root (run with sudo). The AGENT never runs as root; root is only for install/maintenance."
}

have() { command -v "$1" >/dev/null 2>&1; }

# Install apt packages. Under --dry-run on a non-apt host, warns and no-ops so a
# preview works anywhere. Real runs require apt-get (Ubuntu/Debian target).
apt_install() {
  if ! have apt-get; then
    if [ "${DRY_RUN:-0}" = "1" ]; then warn "apt-get not present — would install: $*"; return 0; fi
    die "apt-get not found — this installer targets Ubuntu/Debian VPSes."
  fi
  run env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@"
}

# Validate an agent username: lowercase, starts alpha, [a-z0-9_-], <=32 chars.
valid_username() {
  printf '%s' "$1" | grep -qE '^[a-z][a-z0-9_-]{0,31}$'
}

user_exists()  { id "$1" >/dev/null 2>&1; }
group_exists() { have getent && getent group "$1" >/dev/null 2>&1; }

# Resolve a user's home dir. Uses getent where available; empty if unknown.
user_home() {
  local h=""
  if have getent; then h="$(getent passwd "$1" 2>/dev/null | cut -d: -f6 || true)"; fi
  printf '%s' "$h"
}
