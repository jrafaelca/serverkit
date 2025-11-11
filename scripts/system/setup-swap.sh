#!/usr/bin/env bash

# ===============================================
# Configuración del archivo swap
# ===============================================
# Crea un archivo de intercambio de 1GB si no existe
# y aplica parámetros de rendimiento del kernel.
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Configurando memoria swap..."

SWAPFILE="/swapfile"
SIZE="1G"

# ---------------------------------------------------------------
# Verificar si ya existe swap activo
# ---------------------------------------------------------------
if swapon --show | grep -q "$SWAPFILE"; then
  echo "Swap ya existente. No se requiere acción."

  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Swap]\n"
  SERVERKIT_SUMMARY+="Archivo: ${SWAPFILE}\n"
  SERVERKIT_SUMMARY+="Estado: Ya existente y activo.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"

  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo -e "$SERVERKIT_SUMMARY"
  fi
  exit 0
fi

# ---------------------------------------------------------------
# Crear y activar archivo swap
# ---------------------------------------------------------------
echo "Creando archivo swap de ${SIZE}..."
if fallocate -l "$SIZE" "$SWAPFILE" 2>/dev/null; then
  chmod 600 "$SWAPFILE"
  mkswap "$SWAPFILE" >/dev/null 2>&1

  if swapon "$SWAPFILE" >/dev/null 2>&1; then
    echo "Archivo swap creado y activado correctamente."
  else
    echo "⚠️  Advertencia: No se pudo activar el swap (posible entorno sin soporte)."

    SERVERKIT_SUMMARY+="-------------------------------------------\n"
    SERVERKIT_SUMMARY+="[Swap]\n"
    SERVERKIT_SUMMARY+="Archivo: ${SWAPFILE}\n"
    SERVERKIT_SUMMARY+="Estado: Creado pero no activado.\n"
    SERVERKIT_SUMMARY+="Posible causa: entorno VM o overlayfs.\n"
    SERVERKIT_SUMMARY+="-------------------------------------------\n"

    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
      echo -e "$SERVERKIT_SUMMARY"
    fi
    exit 0
  fi
else
  echo "❌ Error: No se pudo crear el archivo swap (sin soporte fallocate)."

  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Swap]\n"
  SERVERKIT_SUMMARY+="Error: No se pudo crear el archivo swap (sin soporte fallocate).\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"

  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo -e "$SERVERKIT_SUMMARY"
  fi
  exit 1
fi

# ---------------------------------------------------------------
# Configurar persistencia
# ---------------------------------------------------------------
if ! grep -qF "$SWAPFILE" /etc/fstab; then
  echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
  echo "Persistencia del swap añadida en /etc/fstab."
else
  echo "Entrada de persistencia ya existente en /etc/fstab."
fi

# ---------------------------------------------------------------
# Ajustes del kernel
# ---------------------------------------------------------------
# Evita duplicar las líneas en sysctl.conf
sed -i '/vm.swappiness/d' /etc/sysctl.conf 2>/dev/null || true
sed -i '/vm.vfs_cache_pressure/d' /etc/sysctl.conf 2>/dev/null || true

{
  echo "vm.swappiness=30"
  echo "vm.vfs_cache_pressure=50"
} >> /etc/sysctl.conf

sysctl -p >/dev/null 2>&1 || true
echo "Parámetros del kernel ajustados."

# ---------------------------------------------------------------
# Validación final
# ---------------------------------------------------------------
if swapon --show | grep -q "$SWAPFILE"; then
  echo "✅ Configuración de swap completada correctamente."

  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Swap]\n"
  SERVERKIT_SUMMARY+="Archivo: ${SWAPFILE}\n"
  SERVERKIT_SUMMARY+="Tamaño: ${SIZE}\n"
  SERVERKIT_SUMMARY+="Swappiness: 30\n"
  SERVERKIT_SUMMARY+="Cache pressure: 50\n"
  SERVERKIT_SUMMARY+="Estado: activo y persistente.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
else
  echo "❌ Error: El archivo swap no quedó activo."

  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Swap]\n"
  SERVERKIT_SUMMARY+="Archivo: ${SWAPFILE}\n"
  SERVERKIT_SUMMARY+="Estado: Inactivo tras configuración.\n"
  SERVERKIT_SUMMARY+="Revisión manual requerida.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  exit 1
fi

# ---------------------------------------------------------------
# Mostrar resumen si se ejecuta directamente
# ---------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo
  echo "==========================================="
  echo "Configuración de memoria swap"
  echo "==========================================="
  echo -e "$SERVERKIT_SUMMARY"
  echo
fi