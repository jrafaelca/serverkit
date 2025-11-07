#!/usr/bin/env bash
set -e

# ===============================================
# Instalación de PM2 (Administrador de Procesos Node.js)
# ===============================================
# Instala PM2 globalmente para el usuario 'serverkit',
# configura autostart con systemd y habilita rotación
# automática de logs mediante pm2-logrotate.
# ===============================================

[[ -z "${SERVERKIT_ENV_INITIALIZED:-}" ]] && source /opt/serverkit/scripts/common/loader.sh

install_pm2() {
  source /opt/serverkit/scripts/node/install.sh

  local NODE_USER="serverkit"

  log_info "🚀 Instalando PM2 para el usuario '${NODE_USER}'..."

  if ! id "$NODE_USER" &>/dev/null; then
    log_error "❌ El usuario '${NODE_USER}' no existe."
    return 1
  fi

  if ! sudo -u "$NODE_USER" bash -c 'command -v npm >/dev/null 2>&1'; then
    log_warn "⚠️ Node.js no está instalado. Ejecutando install_node()..."
    install_node
  fi

sudo -u "$NODE_USER" bash <<'EOF'


  npm install -g pm2 >/dev/null 2>&1
  pm2 -v || { echo "❌ Error al instalar PM2"; exit 1; }

  pm2 startup systemd -u \$USER --hp \$HOME --silent
  pm2 save >/dev/null 2>&1

  pm2 install pm2-logrotate >/dev/null 2>&1
  pm2 set pm2-logrotate:max_size 100M >/dev/null 2>&1
  pm2 set pm2-logrotate:retain 3 >/dev/null 2>&1
  pm2 set pm2-logrotate:compress true >/dev/null 2>&1
  pm2 set pm2-logrotate:workerInterval 86400 >/dev/null 2>&1
  pm2 set pm2-logrotate:rotateInterval '0 0 * * *' >/dev/null 2>&1
  pm2 save >/dev/null 2>&1

  echo "✅ PM2 instalado y configurado correctamente."
EOF
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && install_pm2 "$@"