#!/usr/bin/env bash
set -e

# ===============================================
# Desinstalación de PM2 (Administrador de Procesos Node.js)
# ===============================================
# Elimina PM2, su configuración, módulos y servicio
# systemd creados para el usuario 'serverkit'.
# ===============================================

[[ -z "${SERVERKIT_ENV_INITIALIZED:-}" ]] && source /opt/serverkit/scripts/common/loader.sh

uninstall_pm2() {
  local NODE_USER="serverkit"
  local NODE_HOME="/home/${NODE_USER}"
  local SERVICE_NAME="pm2-${NODE_USER}.service"
  local PM2_DIR="${NODE_HOME}/.pm2"

  log_info "🧹 Iniciando desinstalación de PM2..."

  if ! id "$NODE_USER" &>/dev/null; then
    log_error "❌ El usuario '${NODE_USER}' no existe."
    return 1
  fi

  # --- Detiene el servicio si existe ---
  if systemctl list-units --type=service | grep -q "$SERVICE_NAME"; then
    log_info "🧩 Deteniendo servicio ${SERVICE_NAME}..."
    systemctl stop "$SERVICE_NAME" >/dev/null 2>&1 || true
    systemctl disable "$SERVICE_NAME" >/dev/null 2>&1 || true
  fi

  # --- Limpia daemon y configuración del usuario ---
sudo -u "$NODE_USER" bash <<'EOF'
  set -e

  export PATH="$HOME/.local/share/fnm:$PATH"
  eval "$(fnm env --shell bash)"

  if command -v pm2 >/dev/null 2>&1; then
    pm2 unstartup systemd >/dev/null 2>&1 || true
    pm2 kill >/dev/null 2>&1 || true

    pm2 uninstall pm2-logrotate >/dev/null 2>&1 || true

    npm uninstall -g pm2 >/dev/null 2>&1 || true
  fi
EOF

  # --- Elimina archivos residuales ---
  if [[ -d "$PM2_DIR" ]]; then
    rm -rf "$PM2_DIR"
  fi

  # --- Elimina unit file del sistema ---
  if [[ -f "/etc/systemd/system/${SERVICE_NAME}" ]]; then
    rm -f "/etc/systemd/system/${SERVICE_NAME}"
    systemctl daemon-reload >/dev/null 2>&1
  fi

  log_info "✅ PM2 desinstalado completamente."
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && uninstall_pm2 "$@"