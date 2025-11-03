#!/usr/bin/env bash
# ===============================================
# Módulo de logging para ServerKit
# ===============================================
# Proporciona funciones estándar para registrar
# información, advertencias y errores en logs.
# ===============================================

# --- Protección contra ejecución directa ---
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && {
  echo "Este archivo no debe ejecutarse directamente."
  exit 1
}

# --- Funciones de logging ---
log_start() {
  {
    echo "==============================================="
    echo "Inicio de módulo: ${SCRIPT_NAME:-desconocido}"
    echo "Host: $(hostname)"
    echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "-----------------------------------------------"
  } >> "$LOG_FILE"
}

log_info() {
  echo "$1" | tee -a "$LOG_FILE"
}

log_warn() {
  echo "WARN: $1" | tee -a "$LOG_FILE"
}

log_error() {
  echo "ERROR: $1" | tee -a "$LOG_FILE" >&2
}

log_end() {
  local duration=$(( $(date +%s) - START_TIME ))
  {
    echo "-----------------------------------------------"
    echo "Finalización de módulo: $SCRIPT_NAME"
    echo "Duración: ${duration}s"
    echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "==============================================="
  } >> "$LOG_FILE"

  if [[ -n "${SERVERKIT_DEFERRED_ACTIONS:-}" && -s "$SERVERKIT_DEFERRED_ACTIONS" ]]; then
    echo ""
    echo "Hay acciones diferidas registradas por ServerKit."
    echo "Cierra esta sesión y vuelve a iniciar para aplicarlas."
    echo ""
  fi
}