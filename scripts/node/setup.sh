#!/usr/bin/env bash

# ===============================================
# setup-node.sh — Instalación y configuración de Node.js
# ===============================================
# Instala NVM, Node.js (LTS) y PNPM de forma global.
# Prepara entorno estándar en /opt/apps/node.
# ===============================================

[[ -z "${SERVERKIT_ENV_INITIALIZED:-}" ]] && source /opt/serverkit/scripts/common/loader.sh

setup_node() {
  log_info "🚀 Configurando entorno Node.js..."

  local NVM_DIR="/usr/local/nvm"
  local PROFILE_SCRIPT="/etc/profile.d/nvm.sh"
  local NODE_APPS="/opt/apps/node"

  # --- Instala NVM si no existe ---
  if [[ -d "$NVM_DIR" ]]; then
    log_info "NVM ya instalado en $NVM_DIR."
  else
    log_info "Instalando NVM..."
    mkdir -p "$NVM_DIR"
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash >/dev/null 2>&1

    # Configuración global de entorno
    cat <<EOF > "$PROFILE_SCRIPT"
export NVM_DIR="$NVM_DIR"
[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
EOF
    chmod 644 "$PROFILE_SCRIPT"

    # 🔹 Cargar NVM en la sesión actual
    export NVM_DIR="$NVM_DIR"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  fi

  # --- Carga NVM (por si ya existía) ---
  export NVM_DIR="$NVM_DIR"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

  # --- Instala Node.js (última LTS estable) ---
  if command -v node >/dev/null 2>&1; then
    log_info "Node.js ya instalado: $(node -v)"
  else
    log_info "Instalando Node.js (LTS)..."
    nvm install --lts >/dev/null 2>&1
    nvm alias default 'lts/*'
    nvm use default >/dev/null 2>&1
  fi

  # --- Habilita Corepack y PNPM ---
  if ! command -v pnpm >/dev/null 2>&1; then
    corepack enable >/dev/null 2>&1
    corepack prepare pnpm@latest --activate >/dev/null 2>&1
  fi

  # --- Estructura estándar para aplicaciones Node ---
  mkdir -p "$NODE_APPS"
  chmod 755 "$NODE_APPS"
  log_info "Directorio base creado: $NODE_APPS"

  # --- Validación final ---
  log_info "Node.js $(node -v) — npm $(npm -v)"
  log_info "PNPM $(pnpm -v)"
  log_info "✅ Entorno Node.js instalado correctamente."
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && setup_node "$@"