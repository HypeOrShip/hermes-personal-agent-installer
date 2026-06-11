#!/usr/bin/env bash
# Slice — OpenViking memory: the agent's persistent brain.
#
# Installs the OpenViking server, runs it as a systemd service on 127.0.0.1:1933,
# and points Hermes at it (built-in MEMORY.md/USER.md + the OpenViking external
# provider). The LLM + embeddings run on OpenAI via LiteLLM — the key is resolved
# at runtime from 1Password by `op run` (op:// reference, never a plain value on
# disk), exactly like the gateway service.
#
# Verified ov.conf schema (read from the OpenViking source + proven on a VPS):
#   vlm + embedding use provider "litellm" (so the key stays in OPENAI_API_KEY env);
#   embedding nests under embedding.dense; storage.workspace is the data dir.
#
# Entry: openviking_install. Requires the OpenAI key (op://VAULT/OpenAI/credential).

OPENVIKING_PORT="${OPENVIKING_PORT:-1933}"

# pip install OpenViking into a venv owned by the agent.
openviking_install_pkg() {
  local user="$1" home="$2"
  local venv="$home/.local/share/openviking-venv"
  step "Installing OpenViking (the memory engine) for '${user}'"
  if [ "${DRY_RUN:-0}" = "1" ]; then warn "would pip install openviking into ${venv}"; return 0; fi
  apt_install python3-venv python3-pip
  run sudo -H -u "$user" python3 -m venv "$venv"
  run sudo -H -u "$user" "$venv/bin/pip" install -q --upgrade pip
  run sudo -H -u "$user" "$venv/bin/pip" install -q openviking
  # OpenViking refuses to run any command before a display language is chosen.
  run sudo -H -u "$user" env HOME="$home" "$venv/bin/ov" language en
  log "openviking installed ($("$venv/bin/pip" show openviking 2>/dev/null | awk '/^Version/{print $2}'))"
}

# Write ov.conf (the verified schema). OpenAI via LiteLLM -> key comes from env.
openviking_write_conf() {
  local user="$1" home="$2"
  local conf="$home/.openviking/ov.conf"
  step "Writing ${conf}"
  if [ "${DRY_RUN:-0}" = "1" ]; then warn "would write ${conf} + create the workspace dir"; return 0; fi
  run install -d -o "$user" -g "$user" -m 0750 "$home/.openviking"
  run install -d -o "$user" -g "$user" -m 0750 "$home/.hermes/data" "$home/.hermes/data/openviking"
  ( umask 027
    cat > "$conf" <<CFG
{
  "default_account": "default",
  "default_user": "default",
  "default_agent": "hermes",
  "storage": { "workspace": "${home}/.hermes/data/openviking" },
  "vlm": { "provider": "litellm", "model": "${OPENVIKING_LLM_MODEL:-openai/gpt-4o-mini}" },
  "embedding": { "dense": { "provider": "litellm", "model": "${OPENVIKING_EMBED_MODEL:-openai/text-embedding-3-small}", "dimension": 1536 } },
  "server": { "host": "127.0.0.1", "port": ${OPENVIKING_PORT} }
}
CFG
  )
  run chown "$user:$user" "$conf"
  log "wrote ${conf}"
}

# Run the OpenViking server as a service — under op run, so OPENAI_API_KEY is
# resolved from 1Password (op://) at runtime, never written to disk.
openviking_service() {
  local user="$1" home="$2"
  local venv="$home/.local/share/openviking-venv"
  step "Installing the OpenViking server service (openviking.service)"
  if [ "${DRY_RUN:-0}" = "1" ]; then warn "would write + start /etc/systemd/system/openviking.service"; return 0; fi
  cat > /etc/systemd/system/openviking.service <<UNIT
[Unit]
Description=OpenViking memory server (the agent's brain)
After=network-online.target
Wants=network-online.target

[Service]
User=${user}
Environment=HOME=${home}
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=-/etc/hermes-agent/op.env
ExecStart=/usr/local/bin/op run --env-file ${home}/.hermes/op-secrets.env -- ${venv}/bin/openviking-server --config ${home}/.openviking/ov.conf
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
  log "wrote /etc/systemd/system/openviking.service"
  run systemctl daemon-reload
  if [ "${APPLY_NETWORK:-1}" = "1" ]; then
    run systemctl enable --now openviking.service
    log "openviking.service enabled + started (127.0.0.1:${OPENVIKING_PORT})"
  else
    warn "APPLY_NETWORK=0 — openviking.service installed but NOT started"
  fi
}

# Restart the gateway so it reconnects with memory now that the server is up.
openviking_restart_gateway() {
  if [ "${APPLY_NETWORK:-1}" = "1" ] && [ "${DRY_RUN:-0}" != "1" ] \
     && systemctl list-unit-files hermes-agent.service >/dev/null 2>&1; then
    run systemctl restart hermes-agent.service && log "gateway restarted with memory on"
  fi
}

openviking_install() {
  local user="${1:?openviking_install: agent user required}"
  need_root
  local home; home="$(user_home "$user")"
  if [ -z "$home" ]; then
    [ "${DRY_RUN:-0}" = "1" ] || die "could not resolve home dir for '${user}'"
    home="/home/${user}"
  fi
  openviking_install_pkg "$user" "$home"
  openviking_write_conf "$user" "$home"
  openviking_service "$user" "$home"
  openviking_restart_gateway
  step "OpenViking memory ready — the agent has a persistent brain on :${OPENVIKING_PORT}."
}
