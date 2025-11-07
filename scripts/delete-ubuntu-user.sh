#!/usr/bin/env bash

# ===============================================
# Eliminación del usuario 'ubuntu'
# ===============================================
# Elimina el usuario predeterminado 'ubuntu' solo si
# existe al menos otro usuario con privilegios sudo.
# ===============================================

# Carga entorno si no está inicializado
[[ -z "${SERVERKIT_ENV_INITIALIZED:-}" ]] && source /opt/serverkit/scripts/common/loader.sh

delete_ubuntu_user() {
  log_start

  # --- Verifica si 'ubuntu' existe ---
  if ! id ubuntu &>/dev/null; then
    log_info "El usuario 'ubuntu' no existe. No se requiere acción."
    return
  fi

  # --- Verifica si existe otro usuario con privilegios sudo ---
  local admin_count
  admin_count=$(getent group sudo | awk -F: '{print NF-2}')
  if (( admin_count < 1 )); then
    log_error "No se detectaron otros usuarios administrativos."
    log_info  "Cree primero un usuario con privilegios sudo antes de eliminar 'ubuntu'."
    return 1
  fi

  # --- Cierra procesos y elimina permisos ---
  pkill -u ubuntu 2>/dev/null || true
  rm -f /etc/sudoers.d/90-cloud-init-users

  # --- Elimina el usuario ---
  if deluser --remove-home ubuntu &>/dev/null; then
    log_info "Usuario 'ubuntu' eliminado correctamente."
  fi

  log_end
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && delete_ubuntu_user "$@"