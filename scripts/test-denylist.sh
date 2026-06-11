#!/usr/bin/env bash
#
# Self-test for scripts/check-denylist.sh. Proves two things:
#   1. The repo as committed is CLEAN (scanner exits 0).
#   2. The scanner CATCHES forbidden examples (scanner exits non-zero).
#
# Forbidden literals below are assembled by concatenation so this test file
# itself contains no full forbidden string — it stays clean under the repo scan.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$ROOT/scripts/check-denylist.sh"
fail=0

echo "== 1/2: repo must be clean =="
if bash "$CHECK"; then
  echo "PASS: repo is clean of denylisted strings"
else
  echo "FAIL: denylist scan flagged the committed repo (see above)"
  fail=1
fi

echo "== 2/2: scanner must catch forbidden fixtures =="
fixtures="$(mktemp -d)"
trap 'rm -rf "$fixtures"' EXIT

# Assemble each forbidden example from parts (no full literal in this source).
priv_script="provision_""agent_finalize.sh"
priv_path="/root/"".hermes"
slack_tok="xox""b-0000000000-1111111111-EXAMPLENOTREALTOKENVALUE"
public_ip="8.8"".""8.8"
tailnet="example-host"".ts"".net"
slack_id="C01""GENERAL99"

{
  printf '%s\n' "$priv_script"
  printf '%s\n' "$priv_path"
  printf '%s\n' "$slack_tok"
  printf '%s\n' "$public_ip"
  printf '%s\n' "$tailnet"
  printf '%s\n' "$slack_id"
} > "$fixtures/violation.txt"

if bash "$CHECK" "$fixtures" >/dev/null 2>&1; then
  echo "FAIL: scanner did NOT flag the forbidden fixtures"
  fail=1
else
  echo "PASS: scanner flagged the forbidden fixtures"
fi

if [ "$fail" -eq 0 ]; then
  echo "ALL DENYLIST TESTS PASSED"
else
  echo "DENYLIST TESTS FAILED"
fi
exit "$fail"
