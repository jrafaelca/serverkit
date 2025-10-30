#!/usr/bin/env bash
set -euo pipefail

# ===============================================
# setup-firewall.sh — Configuración segura del firewall UFW
# ===============================================
# Aplica políticas de red básicas y asegura
# que el servicio UFW esté activo.
# ===============================================

[[ -z "${SERVERKIT_ENV_INITIALIZED:-}" ]] && source /opt/serverkit/common/loader.sh

setup_firewall() {
  log_info "Iniciando configuración del firewall UFW..."

  # --- Detección de entornos gestionados (por ejemplo, AWS EC2 con Security Groups) ---
  if curl -s --connect-timeout 1 http://169.254.169.254/latest/meta-data/ >/dev/null 2>&1; then
    log_info "Entorno administrado detectado (posiblemente AWS). Configuración de UFW omitida."
    return
  fi

  # --- Instalación ---
  if ! command -v ufw >/dev/null 2>&1; then
    log_info "Instalando UFW..."
    apt-get update -y >/dev/null 2>&1
    apt-get install -y ufw >/dev/null 2>&1
  fi

  # --- Configuración básica ---
  ufw --force reset >/dev/null 2>&1 || true
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow 22/tcp comment 'SSH access'

  # --- Activación ---
  ufw --force enable >/dev/null 2>&1
  log_info "UFW habilitado y ejecutándose."

  # --- Asegura persistencia con systemd ---
  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable ufw >/dev/null 2>&1 || true
  fi

  # --- Regla de rotación de logs ---
  CONF_FILE="/etc/logrotate.d/ufw"
  if [[ -f "$CONF_FILE" ]] && ! grep -q "maxsize" "$CONF_FILE"; then
    sed -i -E '/^(\s*)(daily|weekly|monthly|yearly)/a \ \ maxsize 100M' "$CONF_FILE"
    grep -q "maxsize" "$CONF_FILE" || echo "  maxsize 100M" >> "$CONF_FILE"
    log_info "maxsize 100M configurado en $CONF_FILE"
  fi

  # --- Validación final ---
  if ufw status | grep -q "Status: active"; then
    log_info "✅ Firewall UFW configurado correctamente."
  else
    log_error "❌ UFW no se activó correctamente. Verifica con: ufw status"
    return 1
  fi
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && setup_firewall "$@"