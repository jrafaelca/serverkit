#!/usr/bin/env bash
# ===============================================
# Variables de entorno comunes para ServerKit
# ===============================================
# Define variables globales reutilizadas por todos
# los módulos de ServerKit. No ejecuta lógica directa.
# ===============================================

# --- Protección contra ejecución directa ---
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && {
  echo "Este archivo no debe ejecutarse directamente."
  exit 1
}

# --- Configuración base ---
# Habilita modo estricto: error si variable no definida o comando falla
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# --- Directorios y rutas estándar ---
export SERVERKIT_BASE_DIR="/opt/serverkit"
export SERVERKIT_LOG_DIR="/var/log"
export LOG_FILE="$SERVERKIT_LOG_DIR/serverkit.log"

# --- Contexto del script ---
export SCRIPT_NAME="$(basename "${BASH_SOURCE[-1]}")"
export START_TIME="$(date +%s)"
export SERVERKIT_SESSION_ID="$(date +%Y%m%d-%H%M%S)"