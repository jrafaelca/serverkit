#!/usr/bin/env bash

# ===============================================
# Configuración de zona horaria a UTC
# ===============================================
# Establece la zona horaria del sistema en UTC
# utilizando timedatectl (Ubuntu 22.04+ garantizado).
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Ajustando zona horaria del sistema..."

# ---------------------------------------------------------------
# Establecer la zona horaria a UTC
# ---------------------------------------------------------------
if timedatectl set-timezone UTC >/dev/null 2>&1; then
  echo "Zona horaria establecida correctamente en UTC."
else
  echo "❌ Error al establecer la zona horaria mediante timedatectl."

  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Zona horaria]\n"
  SERVERKIT_SUMMARY+="Error: No se pudo aplicar zona UTC mediante timedatectl.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"

  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo
    echo "==========================================="
    echo "Configuración de zona horaria"
    echo "==========================================="
    echo -e "$SERVERKIT_SUMMARY"
    echo
  fi
  exit 1
fi

# ---------------------------------------------------------------
# Validación final
# ---------------------------------------------------------------
CURRENT_TZ=$(date +'%Z %z' 2>/dev/null || echo "Desconocido")

if [[ "$CURRENT_TZ" =~ ^UTC ]]; then
  echo "✅ Validación exitosa: zona horaria activa es UTC."

  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Zona horaria]\n"
  SERVERKIT_SUMMARY+="Zona configurada: UTC\n"
  SERVERKIT_SUMMARY+="Comando aplicado: timedatectl set-timezone UTC\n"
  SERVERKIT_SUMMARY+="Estado: correcto.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
else
  echo "⚠️  Advertencia: zona horaria actual '${CURRENT_TZ}' (no es UTC)."

  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Zona horaria]\n"
  SERVERKIT_SUMMARY+="Zona detectada: ${CURRENT_TZ}\n"
  SERVERKIT_SUMMARY+="Estado: no es UTC, requiere revisión manual.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
fi

# ---------------------------------------------------------------
# Mostrar resumen si se ejecuta directamente
# ---------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo
  echo "==========================================="
  echo "Configuración de zona horaria"
  echo "==========================================="
  echo -e "$SERVERKIT_SUMMARY"
  echo
fi