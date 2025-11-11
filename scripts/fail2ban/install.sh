#!/usr/bin/env bash

# ===============================================
# Instalación y configuración de Fail2Ban
# ===============================================
# Asegura que Fail2Ban esté instalado, activo y con
# una política de rotación de logs de 100 MB.
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Instalando y habilitando Fail2Ban..."

# Verificar si está instalado
if ! command -v fail2ban-client >/dev/null 2>&1; then
  echo "Instalando paquetes de Fail2Ban..."
  apt-get update -y -qq
  apt-get install -y -qq fail2ban
  echo "Fail2Ban instalado correctamente."
else
  echo "Fail2Ban ya estaba instalado."
fi

# Habilitar servicio
systemctl enable --now fail2ban >/dev/null 2>&1 || true
sleep 1

# Validar servicio
if systemctl is-active --quiet fail2ban && fail2ban-client ping >/dev/null 2>&1; then
  echo "Fail2Ban está activo y funcionando correctamente."
else
  echo "Error: el servicio Fail2Ban no se pudo validar. Revisa con: systemctl status fail2ban"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Fail2Ban]\n"
  SERVERKIT_SUMMARY+="Error: el servicio no se encuentra activo.\n"
  SERVERKIT_SUMMARY+="Acción sugerida: systemctl status fail2ban\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo -e "$SERVERKIT_SUMMARY"
  fi
  exit 1
fi

# Ajustar rotación de logs
CONF_FILE="/etc/logrotate.d/fail2ban"
if [[ -f "$CONF_FILE" ]]; then
  if ! grep -q "maxsize" "$CONF_FILE"; then
    sed -i -E '/^(\s*)(daily|weekly|monthly|yearly)/a \ \ maxsize 100M' "$CONF_FILE"
    grep -q "maxsize" "$CONF_FILE" || echo "  maxsize 100M" >> "$CONF_FILE"
    echo "Regla 'maxsize 100M' aplicada en $CONF_FILE."
  fi
else
  echo "Advertencia: no se encontró archivo de logrotate para Fail2Ban."
fi

# Registrar resumen
SERVERKIT_SUMMARY+="-------------------------------------------\n"
SERVERKIT_SUMMARY+="[Fail2Ban]\n"
SERVERKIT_SUMMARY+="Estado: activo y configurado correctamente.\n"
SERVERKIT_SUMMARY+="Servicio: $(systemctl is-active fail2ban)\n"
SERVERKIT_SUMMARY+="Archivo de logrotate: ${CONF_FILE}\n"
SERVERKIT_SUMMARY+="Tamaño máximo de logs: 100M\n"
SERVERKIT_SUMMARY+="-------------------------------------------\n"

# Mostrar resumen si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo -e "$SERVERKIT_SUMMARY"
fi