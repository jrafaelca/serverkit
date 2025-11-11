#!/usr/bin/env bash

# ===============================================
# Desinstalación de PM2 (Administrador de Procesos Node.js)
# ===============================================
# Elimina PM2, su configuración, módulos y servicio
# systemd creados para el usuario 'serverkit'.
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Iniciando desinstalación de PM2..."

NODE_USER="serverkit"
NODE_HOME="/home/${NODE_USER}"
FNM_PATH="${NODE_HOME}/.local/share/fnm"
SERVICE_NAME="pm2-${NODE_USER}.service"
PM2_DIR="${NODE_HOME}/.pm2"

# ---------------------------------------------------------------
# Validar existencia del usuario
# ---------------------------------------------------------------
if ! id "$NODE_USER" &>/dev/null; then
  echo "Error: el usuario '${NODE_USER}' no existe."
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[PM2]\n"
  SERVERKIT_SUMMARY+="Error: el usuario '${NODE_USER}' no existe.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  exit 1
fi

# ---------------------------------------------------------------
# Verificar procesos activos
# ---------------------------------------------------------------
if pgrep -u "$NODE_USER" pm2 >/dev/null 2>&1; then
  echo "Se detectaron procesos PM2 activos. Deteniéndolos..."
  pkill -u "$NODE_USER" pm2 2>/dev/null || true
  sleep 2
fi

# ---------------------------------------------------------------
# Detener servicio systemd si existe
# ---------------------------------------------------------------
if systemctl list-units --type=service | grep -q "$SERVICE_NAME"; then
  echo "Deteniendo servicio ${SERVICE_NAME}..."
  systemctl stop "$SERVICE_NAME" >/dev/null 2>&1 || true
  systemctl disable "$SERVICE_NAME" >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------
# Desinstalar PM2 y limpiar entorno del usuario
# ---------------------------------------------------------------
sudo -u "$NODE_USER" bash <<EOF
set -e
export PATH="${FNM_PATH}:\$PATH"
eval "\$(fnm env --shell bash)"

if command -v pm2 >/dev/null 2>&1; then
  echo "Eliminando procesos PM2..."
  pm2 kill >/dev/null 2>&1 || true

  echo "Desinstalando módulo pm2-logrotate..."
  pm2 uninstall pm2-logrotate >/dev/null 2>&1 || true

  echo "Desregistrando autostart systemd..."
  pm2 unstartup systemd >/dev/null 2>&1 || true

  echo "Desinstalando PM2 global..."
  npm uninstall -g pm2 >/dev/null 2>&1 || true
else
  echo "PM2 no está instalado o no se encontró en el entorno del usuario."
fi
EOF

# ---------------------------------------------------------------
# Eliminar archivos residuales
# ---------------------------------------------------------------
if [[ -d "$PM2_DIR" ]]; then
  echo "Eliminando archivos residuales en ${PM2_DIR}..."
  rm -rf "$PM2_DIR"
fi

# ---------------------------------------------------------------
# Eliminar unidad systemd
# ---------------------------------------------------------------
if [[ -f "/etc/systemd/system/${SERVICE_NAME}" ]]; then
  echo "Eliminando unidad systemd ${SERVICE_NAME}..."
  rm -f "/etc/systemd/system/${SERVICE_NAME}"
  systemctl daemon-reload >/dev/null 2>&1
fi

# ---------------------------------------------------------------
# Validación final
# ---------------------------------------------------------------
PM2_EXISTS=$(sudo -u "$NODE_USER" bash -c 'command -v pm2 >/dev/null 2>&1 && echo yes || echo no')
if [[ "$PM2_EXISTS" == "no" && ! -d "$PM2_DIR" && ! -f "/etc/systemd/system/${SERVICE_NAME}" ]]; then
  STATUS="desinstalado"
  echo "PM2 desinstalado completamente."
else
  STATUS="parcial"
  echo "Advertencia: podrían persistir algunos archivos o configuraciones."
fi

# ---------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------
SERVERKIT_SUMMARY+="-------------------------------------------\n"
SERVERKIT_SUMMARY+="[PM2]\n"
SERVERKIT_SUMMARY+="Estado: ${STATUS}\n"
SERVERKIT_SUMMARY+="Usuario: ${NODE_USER}\n"
SERVERKIT_SUMMARY+="Archivos eliminados: ${PM2_DIR}, /etc/systemd/system/${SERVICE_NAME}\n"
SERVERKIT_SUMMARY+="Entorno FNM cargado desde: ${FNM_PATH}\n"
SERVERKIT_SUMMARY+="Procesos previos: controlados automáticamente.\n"
SERVERKIT_SUMMARY+="-------------------------------------------\n"

# ---------------------------------------------------------------
# Mostrar resumen si se ejecuta directamente
# ---------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo
  echo -e "$SERVERKIT_SUMMARY"
fi