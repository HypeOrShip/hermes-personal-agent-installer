#!/usr/bin/env bash
#
# Clean-room denylist scanner.
#
# Fails (exit 1) if any scanned file contains a forbidden string class:
#   - private on-box provisioning artifacts / privileged paths
#   - secret-shaped tokens
#   - real public IPv4 addresses (documentation/private/loopback ranges allowed)
#   - Slack-style object IDs (C/U/T + alnum, containing a digit)
#   - Tailscale tailnet hostnames
#
# Usage:
#   scripts/check-denylist.sh            # scan all git-tracked files (CI mode)
#   scripts/check-denylist.sh <path>     # scan a file or directory (used by the
#                                          self-test against throwaway fixtures)
#
# Portable to bash 3.2 (macOS) and bash 5 (CI): no mapfile, no \b assertions.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DENY="$ROOT/scripts/denylist.txt"

# The only files excluded from the pattern scan: the denylist definition and
# this scanner. They must contain the patterns by necessity. gitleaks (a
# separate CI step) still scans them, so secrets cannot hide here.
EXCLUDE='^(scripts/denylist\.txt|scripts/check-denylist\.sh)$'

TARGET="${1:-}"

list_files() {
  if [ -n "$TARGET" ]; then
    find "$TARGET" -type f
  else
    ( cd "$ROOT" && git ls-files ) | grep -vE "$EXCLUDE" \
      | while IFS= read -r f; do printf '%s\n' "$ROOT/$f"; done
  fi
}

# Patterns minus comments/blank lines.
PAT="$(mktemp)"
trap 'rm -f "$PAT"' EXIT
grep -vE '^[[:space:]]*(#|$)' "$DENY" > "$PAT" || true

# Core IPv4 shape (no \b — BSD grep lacks it). -o extraction isolates the match.
IPV4='([0-9]{1,3}\.){3}[0-9]{1,3}'
# Allowed: loopback, RFC1918 private, link-local, broadcast, and the RFC5737
# documentation ranges (the correct placeholders for examples/docs).
IP_ALLOW='^(0\.0\.0\.0|127\.|10\.|192\.168\.|169\.254\.|255\.255\.255\.255|192\.0\.2\.|198\.51\.100\.|203\.0\.113\.|172\.(1[6-9]|2[0-9]|3[01])\.)'
# Slack object-id candidate. Filtered to those containing a digit so all-caps
# English words (CONTRIBUTING, UNDERSTANDING, ...) do not false-positive.
SLACK='[CUT][A-Z0-9]{8,11}'

status=0
report() { printf '  %s  [%s]\n' "$1" "$2"; status=1; }

while IFS= read -r f; do
  [ -f "$f" ] || continue

  # 1) literal/regex pattern classes from denylist.txt
  while IFS= read -r line; do
    [ -n "$line" ] && report "$line" "class"
  done < <(grep -nIHEf "$PAT" "$f" 2>/dev/null || true)

  # 2) public IPv4 (skip allowlisted ranges)
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    ip="${line##*:}"
    printf '%s' "$ip" | grep -qE "$IP_ALLOW" && continue
    report "$line" "public-ipv4"
  done < <(grep -nIHoE "$IPV4" "$f" 2>/dev/null || true)

  # 3) Slack-style IDs (must contain a digit to count)
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    id="${line##*:}"
    printf '%s' "$id" | grep -qE '[0-9]' || continue
    report "$line" "slack-id"
  done < <(grep -nIHoE "$SLACK" "$f" 2>/dev/null || true)

done < <(list_files)

if [ "$status" -ne 0 ]; then
  echo "DENYLIST: forbidden strings found (see above)." >&2
else
  echo "DENYLIST: clean."
fi
exit "$status"
