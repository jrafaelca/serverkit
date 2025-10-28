#!/usr/bin/env bash
set -euo pipefail

# ===============================================
# clean-default-user.sh — Eliminación del usuario predeterminado
# ===============================================
# Este script elimina al usuario predeterminado 'ubuntu' en sistemas
# Ubuntu 22.04/24.04 si el usuario 'serverkit' ya está configurado.
# ===============================================

LOG_FILE="/var/log/provision.log"

# --- Verifica permisos ---
# Comprueba que el script se esté ejecutando como root.
if [[ $EUID -ne 0 ]]; then
  echo "❌ Este script debe ejecutarse como root." | tee -a "$LOG_FILE"
  exit 1
fi

# --- Verifica el sistema operativo ---
# Comprueba que el archivo /etc/os-release exista para identificar el sistema operativo.
if [[ ! -f /etc/os-release ]]; then
  echo "❌ No se puede determinar el sistema operativo." | tee -a "$LOG_FILE"
  exit 1
fi

# Carga la información del sistema operativo desde /etc/os-release.
source /etc/os-release

# Verifica que el sistema operativo sea Ubuntu y que la versión sea 22.04 o 24.04.
if [[ "$NAME" != "Ubuntu" || ! " 22.04 24.04 " =~ ${VERSION_ID} ]]; then
  echo "❌ Sistema operativo no soportado." | tee -a "$LOG_FILE"
  exit 1
fi

# --- Elimina el usuario 'ubuntu' ---
# Comprueba si los usuarios 'serverkit' y 'ubuntu' existen antes de proceder.
if id serverkit &>/dev/null && id ubuntu &>/dev/null; then
  echo "Eliminando usuario 'ubuntu'..." | tee -a "$LOG_FILE"

  # Finaliza cualquier proceso en ejecución del usuario 'ubuntu'.
  pkill -u ubuntu || true

  # Elimina el usuario 'ubuntu' y su directorio home. Si falla, intenta eliminar manualmente.
  deluser --remove-home ubuntu || rm -rf /home/ubuntu

  echo "Usuario 'ubuntu' eliminado correctamente." | tee -a "$LOG_FILE"
else
  # Mensaje si no se cumplen las condiciones para eliminar al usuario 'ubuntu'.
  echo "No se cumplen condiciones para eliminar 'ubuntu'." | tee -a "$LOG_FILE"
fi
