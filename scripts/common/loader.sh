#!/usr/bin/env bash
# ===============================================
# Cargador universal de entorno ServerKit
# ===============================================
# Centraliza la inicialización del entorno:
#  - Carga variables globales y utilidades
#  - Verifica permisos y sistema operativo
# ===============================================

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# --- Evita doble carga ---
if [[ -n "${SERVERKIT_ENV_INITIALIZED:-}" ]]; then
  return 0
fi
export SERVERKIT_ENV_INITIALIZED=1

# --- Carga dependencias comunes ---
for lib in \
  "$BASE_DIR/scripts/common/env.sh" \
  "$BASE_DIR/scripts/common/logger.sh" \
  "$BASE_DIR/scripts/common/utils.sh"
do
  [[ -f "$lib" ]] && source "$lib"
done

# --- Validación: ejecución como root ---
if [[ $EUID -ne 0 ]]; then
  echo "Este script debe ejecutarse como root (usa sudo)." >&2
  exit 1
fi
log_info "Permisos root verificados."

# --- Validación: sistema operativo ---
if [[ ! -f /etc/os-release ]]; then
  log_error "No se encontró /etc/os-release. No es posible determinar el sistema operativo."
  exit 1
fi

source /etc/os-release
SUPPORTED_VERSIONS=("22.04" "24.04")

if [[ "$NAME" != "Ubuntu" ]] || [[ ! " ${SUPPORTED_VERSIONS[*]} " =~ ${VERSION_ID} ]]; then
  log_error "Sistema operativo no soportado: $PRETTY_NAME"
  exit 1
fi

log_info "Entorno verificado: $PRETTY_NAME"

# --- Marcador de validación ---
export SERVERKIT_VALIDATED=1