#!/usr/bin/env bash

# ===============================================
# Configuración de rotación de logs
# ===============================================
# Puede ejecutarse directamente o copiarse línea a línea.
# Asegura que logrotate esté instalado y ajusta las reglas
# de rsyslog y ufw para limitar el tamaño máximo de logs.
# ===============================================

[[ -z "${SERVERKIT_ENV_INITIALIZED:-}" ]] && source /opt/serverkit/scripts/common/loader.sh

logrotate_setup() {
  log_info "Iniciando configuración de logrotate..."

  # --- Instalación silenciosa ---
  if ! command -v logrotate >/dev/null 2>&1; then
    log_info "Instalando logrotate..."
    apt-get update -y -qq
    apt-get install -y -qq logrotate
    log_info "logrotate instalado correctamente."
  fi

  # --- Ajuste para rsyslog ---
  if [[ -f "/etc/logrotate.d/rsyslog" ]]; then
    if ! grep -q "maxsize" /etc/logrotate.d/rsyslog; then
      sed -i -E '/^(\s*)(daily|weekly|monthly|yearly)/a \ \ maxsize 100M' /etc/logrotate.d/rsyslog
      grep -q "maxsize" /etc/logrotate.d/rsyslog || echo "  maxsize 100M" >> /etc/logrotate.d/rsyslog
      log_info "maxsize 100M aplicado en /etc/logrotate.d/rsyslog"
    fi
  fi

  # --- Ajuste para ufw ---
  if [[ -f "/etc/logrotate.d/ufw" ]]; then
    if ! grep -q "maxsize" /etc/logrotate.d/ufw; then
      sed -i -E '/^(\s*)(daily|weekly|monthly|yearly)/a \ \ maxsize 100M' /etc/logrotate.d/ufw
      grep -q "maxsize" /etc/logrotate.d/ufw || echo "  maxsize 100M" >> /etc/logrotate.d/ufw
      log_info "maxsize 100M aplicado en /etc/logrotate.d/ufw"
    fi
  fi

  # --- Temporizador ---
  cat > /etc/systemd/system/logrotate.timer <<'EOF'
[Unit]
Description=Ejecutar rotación de logs del sistema
Documentation=man:logrotate(8) man:logrotate.conf(5)

[Timer]
OnCalendar=hourly
AccuracySec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl daemon-reload >/dev/null 2>&1 || true
  systemctl enable --now logrotate.timer >/dev/null 2>&1 || true
  log_info "Temporizador logrotate.timer habilitado y activo."

  log_info "Configuración de logrotate completada correctamente."
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && logrotate_setup "$@"