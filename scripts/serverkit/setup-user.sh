#!/usr/bin/env bash

# ===============================================
# Creación del usuario administrativo 'serverkit'
# ===============================================
# Crea el usuario con privilegios sudo y adm, genera su
# contraseña aleatoria y una clave SSH segura.
# ===============================================

[[ -z "${SERVERKIT_ENV_INITIALIZED:-}" ]] && source /opt/serverkit/scripts/common/loader.sh

setup_serverkit_user() {
  log_info "Iniciando creación del usuario administrativo '${USERNAME}'..."

  USERNAME="serverkit"

  # --- Verifica si ya existe ---
  if id "$USERNAME" &>/dev/null; then
    log_info "✅ Usuario '${USERNAME}' ya existe. Omitiendo creación."
    return
  fi

  # --- Crea usuario y estructura base ---
  useradd -m -s /bin/bash -G sudo,adm "$USERNAME"
  cp /ubuntu/.{profile,bashrc} /home/"$USERNAME"/ 2>/dev/null || true
  chown -R "$USERNAME":"$USERNAME" /home/"$USERNAME"
  chmod 750 /home/"$USERNAME"
  log_info "Directorio y entorno inicial creados."

  # --- Copia claves SSH desde ubuntu si existen ---
  if [[ -d /ubuntu/.ssh ]]; then
    cp -a /ubuntu/.ssh /home/"$USERNAME"/
    chown -R "$USERNAME":"$USERNAME" /home/"$USERNAME"/.ssh
    log_info "Claves SSH copiadas desde ubuntu."
  fi

  # --- Genera contraseña aleatoria ---
  RAW_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-16)
  echo "${USERNAME}:${RAW_PASSWORD}" | chpasswd
  log_info "Contraseña temporal generada."

  # --- Genera clave SSH ed25519 ---
  mkdir -p /home/"$USERNAME"/.ssh
  SSH_KEY="/home/${USERNAME}/.ssh/id_rsa"
  if [[ ! -f "$SSH_KEY" ]]; then
    ssh-keygen -q -t ed25519 -f "$SSH_KEY" -N '' -C "${USERNAME}@$(hostname -I | awk '{print $1}')"
    chown -R "$USERNAME":"$USERNAME" /home/"$USERNAME"/.ssh
    chmod 700 /home/"$USERNAME"/.ssh
    chmod 600 "$SSH_KEY"
    log_info "Clave SSH ed25519 generada correctamente."
  fi

  # --- Validación final ---
  if id "$USERNAME" &>/dev/null && [[ -d /home/"$USERNAME" ]]; then
    log_info "✅ Usuario '${USERNAME}' creado correctamente."

    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
      echo ""
      echo "   👤 Usuario: ${USERNAME}"
      echo "   🔐 Contraseña: ${RAW_PASSWORD}"
      echo "   👥 Grupos: $(id -nG "$USERNAME")"
      echo "   📁 Directorio: /home/${USERNAME}"
      echo ""
    fi
  else
    log_error "❌ Error al crear el usuario '${USERNAME}'."
    return 1
  fi
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && setup_serverkit_user "$@"