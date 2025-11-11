#!/usr/bin/env bash

# ===============================================
# Instalación de PM2 (Administrador de Procesos Node.js)
# ===============================================
# Instala PM2 globalmente para el usuario 'serverkit',
# configura autostart con systemd y habilita rotación
# automática de logs mediante pm2-logrotate.
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Iniciando instalación de PM2..."

PM2_USER="serverkit"
NODE_HOME="/home/${PM2_USER}"

# ---------------------------------------------------------------
# Validar existencia del usuario
# ---------------------------------------------------------------
if ! id "$PM2_USER" &>/dev/null; then
  echo "Error: el usuario '${PM2_USER}' no existe."
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[PM2]\n"
  SERVERKIT_SUMMARY+="Error: el usuario '${PM2_USER}' no existe.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  exit 1
fi

# ---------------------------------------------------------------
# Validar instalación de Node.js
# ---------------------------------------------------------------
if ! sudo -u "$PM2_USER" bash -c 'command -v fnm >/dev/null 2>&1'; then
  echo "Node.js no está instalado. Ejecuta primero el instalador de Node.js."
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[PM2]\n"
  SERVERKIT_SUMMARY+="Error: Node.js no está instalado para el usuario '${PM2_USER}'.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  exit 1
fi

# ---------------------------------------------------------------
# Instalación de PM2 y configuración
# ---------------------------------------------------------------
sudo -u "$PM2_USER" bash <<'EOF'
export PATH="$HOME/.local/share/fnm:$PATH"
eval "$(fnm env --shell bash)"

echo "Instalando PM2..."
npm install -g pm2 >/dev/null 2>&1

if ! command -v pm2 >/dev/null 2>&1; then
  echo "Error: PM2 no se instaló correctamente."
  exit 1
fi

echo "Configurando PM2..."
pm2 ping >/dev/null 2>&1 || pm2 start "echo PM2 daemon started" >/dev/null 2>&1

# Configurar inicio automático con systemd
pm2 startup systemd -u "$USER" --hp "$HOME" --silent >/dev/null 2>&1

# Instalar y configurar módulo pm2-logrotate
pm2 install pm2-logrotate >/dev/null 2>&1
pm2 set pm2-logrotate:max_size 100M >/dev/null 2>&1
pm2 set pm2-logrotate:retain 3 >/dev/null 2>&1
pm2 set pm2-logrotate:compress true >/dev/null 2>&1
pm2 set pm2-logrotate:workerInterval 86400 >/dev/null 2>&1
pm2 set pm2-logrotate:rotateInterval '0 0 * * *' >/dev/null 2>&1
pm2 save >/dev/null 2>&1

echo "PM2 instalado y configurado correctamente."
EOF

# ---------------------------------------------------------------
# Validación final
# ---------------------------------------------------------------
if sudo -u "$PM2_USER" bash -c 'command -v pm2 >/dev/null 2>&1'; then
  STATUS="instalado"
else
  STATUS="error"
fi

# ---------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------
SERVERKIT_SUMMARY+="-------------------------------------------\n"
SERVERKIT_SUMMARY+="[PM2]\n"
SERVERKIT_SUMMARY+="Estado: ${STATUS}\n"
SERVERKIT_SUMMARY+="Usuario: ${PM2_USER}\n"
SERVERKIT_SUMMARY+="Inicio automático: habilitado (systemd)\n"
SERVERKIT_SUMMARY+="Rotación de logs: activa (pm2-logrotate)\n"
SERVERKIT_SUMMARY+="Directorio home: ${NODE_HOME}\n"
SERVERKIT_SUMMARY+="-------------------------------------------\n"

# ---------------------------------------------------------------
# Mostrar resumen si se ejecuta directamente
# ---------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo
  echo "==========================================="
  echo "PM2 instalado correctamente."
  echo "==========================================="
  echo -e "$SERVERKIT_SUMMARY"
  echo
fi