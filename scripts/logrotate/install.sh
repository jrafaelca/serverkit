#!/usr/bin/env bash

# ===============================================
# Configuración de rotación de logs
# ===============================================
# Asegura que logrotate esté instalado y ajusta las reglas
# de rsyslog y ufw para limitar el tamaño máximo de logs.
# Además, habilita un temporizador systemd para ejecutarlo
# de forma horaria.
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Iniciando instalación y configuración de Logrotate..."

# ---------------------------------------------------------------
# Verificar si logrotate está instalado
# ---------------------------------------------------------------
if ! command -v logrotate >/dev/null 2>&1; then
  echo "Instalando logrotate..."
  apt-get update -y -qq
  apt-get install -y -qq logrotate
  echo "Logrotate instalado correctamente."
else
  echo "Logrotate ya estaba instalado. Omitiendo instalación."
fi

# ---------------------------------------------------------------
# Ajustar configuración para rsyslog
# ---------------------------------------------------------------
if [[ -f "/etc/logrotate.d/rsyslog" ]]; then
  if ! grep -q "maxsize" /etc/logrotate.d/rsyslog; then
    sed -i -E '/^(\s*)(daily|weekly|monthly|yearly)/a \ \ maxsize 100M' /etc/logrotate.d/rsyslog
    grep -q "maxsize" /etc/logrotate.d/rsyslog || echo "  maxsize 100M" >> /etc/logrotate.d/rsyslog
    echo "Regla 'maxsize 100M' aplicada en /etc/logrotate.d/rsyslog."
  else
    echo "Regla 'maxsize' ya existe en /etc/logrotate.d/rsyslog."
  fi
else
  echo "Advertencia: No se encontró /etc/logrotate.d/rsyslog."
fi

# ---------------------------------------------------------------
# Ajustar configuración para ufw
# ---------------------------------------------------------------
if [[ -f "/etc/logrotate.d/ufw" ]]; then
  if ! grep -q "maxsize" /etc/logrotate.d/ufw; then
    sed -i -E '/^(\s*)(daily|weekly|monthly|yearly)/a \ \ maxsize 100M' /etc/logrotate.d/ufw
    grep -q "maxsize" /etc/logrotate.d/ufw || echo "  maxsize 100M" >> /etc/logrotate.d/ufw
    echo "Regla 'maxsize 100M' aplicada en /etc/logrotate.d/ufw."
  else
    echo "Regla 'maxsize' ya existe en /etc/logrotate.d/ufw."
  fi
else
  echo "Advertencia: No se encontró /etc/logrotate.d/ufw."
fi

# ---------------------------------------------------------------
# Crear temporizador de systemd
# ---------------------------------------------------------------
if pidof systemd &>/dev/null; then
  if [[ ! -f /etc/systemd/system/logrotate.timer ]]; then
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
    echo "Temporizador logrotate.timer creado, habilitado y activo."
  else
    echo "Temporizador logrotate.timer ya existe, omitiendo creación."
  fi
else
  echo "Advertencia: systemd no está disponible. Se omite creación del temporizador."
fi

# ---------------------------------------------------------------
# Validación final
# ---------------------------------------------------------------
if command -v logrotate >/dev/null 2>&1 && systemctl is-active --quiet logrotate.timer 2>/dev/null; then
  echo "Configuración de Logrotate completada correctamente."

  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Logrotate]\n"
  SERVERKIT_SUMMARY+="Estado: instalado y configurado correctamente.\n"
  SERVERKIT_SUMMARY+="Temporizador: habilitado (ejecución horaria).\n"
  SERVERKIT_SUMMARY+="Límites aplicados: maxsize 100M para rsyslog y ufw.\n"
  SERVERKIT_SUMMARY+="Archivos de configuración:\n"
  SERVERKIT_SUMMARY+=" - /etc/logrotate.d/rsyslog\n"
  SERVERKIT_SUMMARY+=" - /etc/logrotate.d/ufw\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
else
  echo "Error: Logrotate o su temporizador no se configuraron correctamente."

  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Logrotate]\n"
  SERVERKIT_SUMMARY+="Error: la configuración no pudo completarse.\n"
  SERVERKIT_SUMMARY+="Requiere verificación manual.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  exit 1
fi

# ---------------------------------------------------------------
# Mostrar resumen si se ejecuta directamente
# ---------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo
  echo "==========================================="
  echo "Logrotate instalado y configurado correctamente."
  echo "==========================================="
  echo -e "$SERVERKIT_SUMMARY"
  echo
fi