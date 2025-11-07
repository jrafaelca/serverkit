#!/usr/bin/env bash
set -e

# ===============================================
# Instalación de Node.js (via FNM)
# ===============================================
# Instala FNM, Node.js (LTS) y PNPM usando las rutas
# por defecto del usuario 'serverkit'.
# Configura automáticamente el entorno de shell.
# ===============================================

[[ -z "${SERVERKIT_ENV_INITIALIZED:-}" ]] && source /opt/serverkit/scripts/common/loader.sh

install_node() {
  local NODE_USER="serverkit"
  local NODE_HOME="/home/${NODE_USER}"
  local NODE_APPS="/opt/apps/node"
  local SHELL_RC="${NODE_HOME}/.bashrc"

  log_info "🚀 Instalando Node.js y FNM..."

  # --- Verifica que el usuario exista ---
  if ! id "$NODE_USER" &>/dev/null; then
    log_error "❌ El usuario '${NODE_USER}' no existe. Debes crearlo antes de ejecutar este script."
    return 1
  fi

  # --- Ejecuta instalación bajo el usuario 'serverkit' ---
sudo -u "$NODE_USER" bash <<'EOF'
  set -e

  if ! command -v fnm >/dev/null 2>&1; then
    curl -fsSL https://fnm.vercel.app/install | bash >/dev/null 2>&1
  fi

  export PATH="$HOME/.local/share/fnm:$PATH"
  eval "$(fnm env --shell bash)"

  fnm install --lts
  fnm default lts-latest
  fnm use default

  corepack enable
  corepack prepare pnpm@latest --activate

  echo "✅ Node.js $(node -v) — NPM $(npm -v) — PNPM $(pnpm -v) instalados correctamente."
EOF

  # --- Crea estructura base para apps Node ---
  mkdir -p "$NODE_APPS"
  chown -R "$NODE_USER":"$NODE_USER" "$NODE_APPS"
  chmod 755 "$NODE_APPS"
  log_info "📁 Directorio de aplicaciones Node: ${NODE_APPS}"

  # --- Configura shell para carga automática ---
  if ! grep -q 'fnm env' "$SHELL_RC"; then
    echo 'eval "$(fnm env --use-on-cd --shell bash)"' >> "$SHELL_RC"
    chown "$NODE_USER":"$NODE_USER" "$SHELL_RC"
  fi
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && install_node "$@"