#!/usr/bin/env bash

# ===============================================
# Eliminación del usuario 'ubuntu'
# ===============================================
# Elimina el usuario predeterminado 'ubuntu' solo si
# existe al menos otro usuario con privilegios sudo.
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Eliminando usuario 'ubuntu' del sistema..."

# Verificar si 'ubuntu' existe
if ! id ubuntu &>/dev/null; then
  echo "El usuario 'ubuntu' no existe. No se requiere acción."

  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Eliminación de usuario 'ubuntu']\n"
  SERVERKIT_SUMMARY+="Estado: No se requiere acción (usuario inexistente).\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"

  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo -e "$SERVERKIT_SUMMARY"
  fi
  exit 0
fi

# Verificar que exista al menos otro usuario con privilegios sudo
admin_users=$(getent group sudo | awk -F: '{print $4}' | tr ',' '\n' | grep -v '^ubuntu$' | xargs)
if [[ -z "$admin_users" ]]; then
  echo "No se detectaron otros usuarios administrativos."
  echo "Debe crear primero un usuario con privilegios sudo antes de eliminar 'ubuntu'."

  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Eliminación de usuario 'ubuntu']\n"
  SERVERKIT_SUMMARY+="Error: No se detectaron otros usuarios con privilegios sudo.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"

  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo -e "$SERVERKIT_SUMMARY"
  fi
  exit 1
fi

# Cerrar procesos activos y eliminar permisos
pkill -u ubuntu 2>/dev/null || true
rm -f /etc/sudoers.d/90-cloud-init-users 2>/dev/null || true

# Eliminar usuario y su home
if deluser --remove-home ubuntu &>/dev/null; then
  echo "Usuario 'ubuntu' eliminado correctamente."

  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Eliminación de usuario 'ubuntu']\n"
  SERVERKIT_SUMMARY+="Estado: Usuario eliminado correctamente.\n"
  SERVERKIT_SUMMARY+="Usuarios administrativos restantes: ${admin_users}\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
else
  echo "Error al eliminar el usuario 'ubuntu'."

  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Eliminación de usuario 'ubuntu']\n"
  SERVERKIT_SUMMARY+="Error: Fallo al ejecutar 'deluser --remove-home ubuntu'.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"

  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo -e "$SERVERKIT_SUMMARY"
  fi
  exit 1
fi

# Mostrar resumen si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo
  echo "==========================================="
  echo "Eliminación de usuario 'ubuntu'"
  echo "==========================================="
  echo -e "$SERVERKIT_SUMMARY"
  echo
fi