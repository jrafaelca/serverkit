#!/usr/bin/env bash
set -euo pipefail

# ===============================================
# Configuración de zona horaria a UTC
# ===============================================
# Establece la zona horaria del sistema en UTC.
# Compatible tanto con sistemas con systemd como sin él.
# ===============================================

[[ -z "${SERVERKIT_ENV_INITIALIZED:-}" ]] && source /opt/serverkit/scripts/common/loader.sh

timezone_setup() {
  log_info "Iniciando configuración de zona horaria a UTC..."

  # --- Intenta establecer la zona horaria ---
  if command -v timedatectl >/dev/null 2>&1; then
    timedatectl set-timezone UTC >/dev/null 2>&1 || log_warn "No se pudo aplicar la zona horaria mediante timedatectl."
  elif [ -f /etc/localtime ]; then
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime
  else
    log_warn "No se detectó mecanismo para establecer zona horaria. Verifica manualmente."
  fi

  # --- Validación final ---
  CURRENT_TZ=$(date +'%Z %z')
  if [[ "$CURRENT_TZ" == "UTC +0000" || "$CURRENT_TZ" == "UTC" ]]; then
    log_info "✅ Zona horaria configurada correctamente en UTC."
  else
    log_warn "⚠️ Zona horaria actual: $CURRENT_TZ (no es UTC)."
  fi
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && timezone_setup "$@"