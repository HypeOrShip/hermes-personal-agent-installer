#!/usr/bin/env bash
# Slice — persona: the friendly front door.
#
# Authors the agent's SOUL.md ("who you are") + USER.md ("who I am") from a short
# INTERVIEW (no nano on the box), and writes a ready-to-paste Codex/ChatGPT
# avatar prompt. Order of preference: 1Password persona fields (the fully
# no-terminal path) -> the interview -> keep the starter files (e.g. in CI).
#
# Entry: persona_install.  Env: PERSONA_SKIP=1 to skip; reads
# op://VAULT/Agent/{soul,user} if the user pre-filled them.

PERSONA_SOUL=""
PERSONA_USER=""

# A persona doc the user pre-filled in 1Password (the no-terminal path), or empty.
persona_from_1p() {
  if [ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && have op; then
    op read "op://${OP_VAULT:-YOUR_VAULT}/Agent/${1}" 2>/dev/null || true
  fi
}

# Interactive interview. Sets PERSONA_SOUL/PERSONA_USER, returns 0; or returns 1
# to skip (PERSONA_SKIP=1, or no terminal — e.g. CI / piped install).
persona_interview() {
  [ "${PERSONA_SKIP:-0}" = "1" ] && return 1
  [ -t 0 ] || return 1
  local name role tone pb uname uwork uhelp pbline
  printf '\n  Give your agent a personality (press Enter to keep the default).\n\n' >&2
  read -r -p "  Agent name [Hermes]: " name;                          name="${name:-Hermes}"
  read -r -p "  One-line role [a personal assistant]: " role;         role="${role:-a personal assistant}"
  read -r -p "  Tone (e.g. warm, blunt, witty) [direct and warm]: " tone; tone="${tone:-direct and warm}"
  read -r -p "  Push back when you're wrong? (y/n) [y]: " pb;         pb="${pb:-y}"
  printf '\n  Now, about you:\n\n' >&2
  read -r -p "  Your name / what you do: " uname
  read -r -p "  What you want help with day to day: " uwork
  read -r -p "  How you like to be helped: " uhelp
  case "${pb:0:1}" in
    n|N) pbline="Do what you're asked, efficiently." ;;
    *)   pbline="Push back honestly when something's a bad idea — you're a thinking partner, not a yes-bot." ;;
  esac
  PERSONA_SOUL="# SOUL — who you are

You are **${name}**, ${role}. You live on your own server and run 24/7.

- Tone: ${tone}.
- ${pbline}
- Keep replies tight. No filler.
- You can run tools and code on this box; do so when it genuinely helps."
  PERSONA_USER="# USER — who I am

- ${uname:-[who you are / what you do]}
- I want help with: ${uwork:-[your day to day]}
- How I like help: ${uhelp:-[tone, detail level, what to never do]}"
  return 0
}

persona_write() {
  local user="$1" home="$2"
  local soul_1p user_1p
  soul_1p="$(persona_from_1p soul)"
  user_1p="$(persona_from_1p user)"
  if [ -n "$soul_1p" ] || [ -n "$user_1p" ]; then
    step "Writing SOUL.md + USER.md from your 1Password persona fields"
    [ "${DRY_RUN:-0}" = "1" ] && { warn "would write SOUL/USER from 1Password"; return 0; }
    [ -n "$soul_1p" ] && printf '%s\n' "$soul_1p" > "$home/.hermes/SOUL.md"
    [ -n "$user_1p" ] && printf '%s\n' "$user_1p" > "$home/.hermes/USER.md"
  elif persona_interview; then
    step "Writing SOUL.md + USER.md from your answers"
    [ "${DRY_RUN:-0}" = "1" ] && { warn "would write SOUL/USER from the interview"; return 0; }
    printf '%s\n' "$PERSONA_SOUL" > "$home/.hermes/SOUL.md"
    printf '%s\n' "$PERSONA_USER" > "$home/.hermes/USER.md"
  else
    warn "no terminal + no 1Password persona fields — keeping the starter SOUL.md/USER.md (edit them anytime)"
    return 0
  fi
  run chown "$user:$user" "$home/.hermes/SOUL.md" "$home/.hermes/USER.md"
  log "persona written"
}

# Write a ready-to-paste avatar prompt (the on-camera Codex moment).
persona_avatar() {
  local user="$1" home="$2"
  local out="$home/.hermes/avatar-prompt.txt"
  step "Writing the avatar prompt (paste into Codex/ChatGPT to make the agent's face)"
  if [ "${DRY_RUN:-0}" = "1" ]; then warn "would write ${out}"; return 0; fi
  {
    echo "# Paste this into Codex / ChatGPT to generate a 512x512 Slack app icon:"
    echo
    echo "Square app icon, 512x512. Minimalist flat-illustration portrait of the agent"
    echo "described in the SOUL below — expression + palette matching its personality."
    echo "Clean modern vector style, strong silhouette readable at small Slack-avatar size."
    echo "No text."
    echo
    echo "--- SOUL (for context) ---"
    cat "$home/.hermes/SOUL.md" 2>/dev/null || true
  } > "$out"
  run chown "$user:$user" "$out"
  log "avatar prompt -> ${out}"
  printf '\n  🎨 Avatar prompt ready: %s\n     Paste it into Codex/ChatGPT to generate your agent'"'"'s face.\n\n' "$out" >&2
}

persona_install() {
  local user="${1:?persona_install: agent user required}"
  need_root
  local home; home="$(user_home "$user")"
  if [ -z "$home" ]; then
    [ "${DRY_RUN:-0}" = "1" ] || die "could not resolve home dir for '${user}'"
    home="/home/${user}"
  fi
  persona_write "$user" "$home"
  persona_avatar "$user" "$home"
  if [ "${APPLY_NETWORK:-1}" = "1" ] && [ "${DRY_RUN:-0}" != "1" ] \
     && systemctl list-unit-files hermes-agent.service >/dev/null 2>&1; then
    run systemctl restart hermes-agent.service && log "gateway restarted with the new persona"
  fi
  step "Persona set — your agent knows who it is, and who you are."
}
