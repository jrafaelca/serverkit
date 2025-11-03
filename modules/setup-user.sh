#!/usr/bin/env bash
set -euo pipefail

# ===============================================
# setup-user.sh — Creación del usuario administrativo 'serverkit'
# ===============================================
# Crea el usuario con privilegios sudo, genera su
# contraseña aleatoria y una clave SSH segura.
# ===============================================

[[ -z "${SERVERKIT_ENV_INITIALIZED:-}" ]] && source /opt/serverkit/common/loader.sh

setup_user() {
  log_info "Iniciando creación del usuario administrativo 'serverkit'..."

  # --- Verifica si ya existe ---
  if id serverkit &>/dev/null; then
    log_info "✅ Usuario 'serverkit' ya existe. Omitiendo creación."
    return
  fi

  # --- Crea usuario y estructura base ---
  useradd -m -s /bin/bash -G sudo serverkit
  cp /ubuntu/.{profile,bashrc} /home/serverkit/ 2>/dev/null || true
  chown -R serverkit:serverkit /home/serverkit
  chmod 750 /home/serverkit
  log_info "Directorio y entorno inicial creados."

  # --- Copia claves SSH desde ubuntu si existen ---
  if [[ -d /ubuntu/.ssh ]]; then
    cp -a /ubuntu/.ssh /home/serverkit/
    chown -R serverkit:serverkit /home/serverkit/.ssh
    log_info "Claves SSH copiadas desde ubuntu."
  fi

  # --- Genera contraseña aleatoria ---
  RAW_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-16)
  echo "serverkit:${RAW_PASSWORD}" | chpasswd
  log_info "Contraseña temporal generada."

  # --- Genera clave SSH ed25519 ---
  mkdir -p /home/serverkit/.ssh
  SSH_KEY="/home/serverkit/.ssh/id_rsa"
  if [[ ! -f "$SSH_KEY" ]]; then
    ssh-keygen -q -t ed25519 -f "$SSH_KEY" -N '' -C "serverkit@$(hostname -I | awk '{print $1}')"
    chown -R serverkit:serverkit /home/serverkit/.ssh
    chmod 700 /home/serverkit/.ssh
    chmod 600 "$SSH_KEY"
    log_info "Clave SSH ed25519 generada correctamente."
  fi

  # --- Validación final ---
  if id serverkit &>/dev/null && [[ -d /home/serverkit ]]; then
    log_info "✅ Usuario 'serverkit' creado correctamente."
    echo ""
    echo "   🔐 Contraseña temporal: ${RAW_PASSWORD}"
    echo "   📁 Directorio: /home/serverkit"
    echo ""
  else
    log_error "❌ Error al crear el usuario 'serverkit'."
    return 1
  fi
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && setup_user "$@"