#!/usr/bin/env bash
set -euo pipefail

# ===============================================
# setup-fail2ban.sh — Instalación y configuración de Fail2Ban
# ===============================================
# Puede ejecutarse directamente:
#   sudo bash setup-fail2ban.sh
# o copiarse y ejecutar los comandos manualmente.
# ===============================================

[[ -z "${SERVERKIT_ENV_INITIALIZED:-}" ]] && source /opt/serverkit/common/loader.sh

setup_fail2ban() {
  log_info "Iniciando instalación y configuración de Fail2Ban..."

  # --- Instalación ---
  if ! command -v fail2ban-client >/dev/null 2>&1; then
    log_info "Instalando Fail2Ban..."
    apt-get update -y >/dev/null 2>&1
    apt-get install -y fail2ban >/dev/null 2>&1
  fi

  # --- Servicio ---
  systemctl enable --now fail2ban >/dev/null 2>&1 || true
  sleep 1

  # --- Validación del servicio ---
  if ! systemctl is-active --quiet fail2ban || ! fail2ban-client ping >/dev/null 2>&1; then
    log_error "❌ Fallo al iniciar o validar Fail2Ban. Revisa el servicio con: systemctl status fail2ban"
    return 1
  fi

  log_info "✅ Servicio Fail2Ban activo y funcionando correctamente."

  # --- Ajuste de rotación de logs ---
  CONF_FILE="/etc/logrotate.d/fail2ban"
  if [[ -f "$CONF_FILE" ]] && ! grep -q "maxsize" "$CONF_FILE"; then
    sed -i -E '/^(\s*)(daily|weekly|monthly|yearly)/a \ \ maxsize 100M' "$CONF_FILE"
    grep -q "maxsize" "$CONF_FILE" || echo "  maxsize 50M" >> "$CONF_FILE"
  fi

  log_info "✅ Configuración de Fail2Ban completada correctamente."
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && setup_fail2ban "$@"