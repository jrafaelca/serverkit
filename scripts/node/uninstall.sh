#!/usr/bin/env bash
set -e

# ===============================================
# Desinstalación de Node.js (via FNM)
# ===============================================
# Elimina FNM, Node.js y PNPM del usuario 'serverkit'
# sin afectar configuraciones globales del sistema.
# ===============================================

[[ -z "${SERVERKIT_ENV_INITIALIZED:-}" ]] && source /opt/serverkit/scripts/common/loader.sh

uninstall_node() {
  local NODE_USER="serverkit"
  local NODE_HOME="/home/${NODE_USER}"
  local FNM_PATH="${NODE_HOME}/.local/share/fnm"
  local SHELL_RC="${NODE_HOME}/.bashrc"
  local NODE_APPS="/opt/apps/node"

  log_info "🧹 Eliminando Node.js y FNM'..."

  # --- Verifica que el usuario exista ---
  if ! id "$NODE_USER" &>/dev/null; then
    log_error "❌ El usuario '${NODE_USER}' no existe."
    return 1
  fi

  # --- Termina procesos relacionados ---
  pkill -u "$NODE_USER" node 2>/dev/null || true
  pkill -u "$NODE_USER" pm2 2>/dev/null || true

  # --- Limpia archivos del entorno FNM ---
  sudo -u "$NODE_USER" bash <<'EOF'
    rm -rf ~/.fnm
    rm -rf ~/.local/share/fnm
    rm -rf ~/.cache/{node,npm,fnm}
EOF

  # --- Limpia bloque FNM completo del shell ---
  if grep -q '# fnm' "$SHELL_RC"; then
    sed -i '/# fnm/,/fi/d' "$SHELL_RC" 2>/dev/null || true
  fi

  # --- Limpia directorio de apps ---
  rm -rf "$NODE_APPS"/* || true

  log_info "✅ Desinstalación completada. Entorno Node.js removido."
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && uninstall_node "$@"