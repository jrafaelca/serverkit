#!/usr/bin/env bash

# ===============================================
# Creación del usuario administrativo
# ===============================================
# Crea el usuario 'serverkit' con privilegios sudo/adm,
# copia entorno desde ubuntu, genera una contraseña única
# y crea claves SSH ed25519 si no existen.
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Creando usuario administrativo..."

SERVERKIT_USERNAME="serverkit"
SERVERKIT_HOME="/home/${SERVERKIT_USERNAME}"
SSH_DIR="${SERVERKIT_HOME}/.ssh"
SSH_KEY="${SSH_DIR}/id_ed25519"
SSH_PUB="${SSH_KEY}.pub"

# ---------------------------------------------------------------
# Verificar si el usuario ya existe
# ---------------------------------------------------------------
if id "$SERVERKIT_USERNAME" &>/dev/null; then
  echo "El usuario '${SERVERKIT_USERNAME}' ya existe. Omitiendo creación."

  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Usuario administrativo]\n"
  SERVERKIT_SUMMARY+="Usuario '${SERVERKIT_USERNAME}' ya existía previamente.\n"
  SERVERKIT_SUMMARY+="Ruta: ${SERVERKIT_HOME}\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"

  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo -e "$SERVERKIT_SUMMARY"
  fi
  exit 0
fi

# ---------------------------------------------------------------
# Crear usuario y estructura base
# ---------------------------------------------------------------
useradd -m -s /bin/bash -G sudo,adm "$SERVERKIT_USERNAME"
cp /ubuntu/.{profile,bashrc} "$SERVERKIT_HOME"/ 2>/dev/null || true
chown -R "$SERVERKIT_USERNAME":"$SERVERKIT_USERNAME" "$SERVERKIT_HOME"
chmod 750 "$SERVERKIT_HOME"
echo "Usuario '${SERVERKIT_USERNAME}' creado y entorno inicial configurado."

# ---------------------------------------------------------------
# Copiar claves SSH desde ubuntu si existen
# ---------------------------------------------------------------
if [[ -d /ubuntu/.ssh ]]; then
  cp -a /ubuntu/.ssh "$SERVERKIT_HOME"/
  chown -R "$SERVERKIT_USERNAME":"$SERVERKIT_USERNAME" "$SSH_DIR"
  chmod 700 "$SSH_DIR"
  chmod 600 "$SSH_DIR"/id_* 2>/dev/null || true
  echo "Claves SSH copiadas desde el usuario 'ubuntu'."
fi

# ---------------------------------------------------------------
# Generar contraseña única
# ---------------------------------------------------------------
SERVERKIT_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-16)
echo "${SERVERKIT_USERNAME}:${SERVERKIT_PASSWORD}" | chpasswd
passwd -e "$SERVERKIT_USERNAME" >/dev/null 2>&1 || true
echo "Contraseña temporal generada."

# ---------------------------------------------------------------
# Generar clave SSH ed25519
# ---------------------------------------------------------------
mkdir -p "$SSH_DIR"
if [[ ! -f "$SSH_KEY" ]]; then
  ssh-keygen -q -t ed25519 -f "$SSH_KEY" -N '' -C "${SERVERKIT_USERNAME}@$(hostname -I | awk '{print $1}')"
  chown -R "$SERVERKIT_USERNAME":"$SERVERKIT_USERNAME" "$SSH_DIR"
  chmod 700 "$SSH_DIR"
  chmod 600 "$SSH_KEY"
  echo "Clave SSH ed25519 generada correctamente."
fi

# ---------------------------------------------------------------
# Validar creación y registrar resumen
# ---------------------------------------------------------------
if id "$SERVERKIT_USERNAME" &>/dev/null && [[ -d "$SERVERKIT_HOME" ]]; then
  echo "Usuario '${SERVERKIT_USERNAME}' creado correctamente."

  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Usuario administrativo]\n"
  SERVERKIT_SUMMARY+="Nombre: ${SERVERKIT_USERNAME}\n"
  SERVERKIT_SUMMARY+="Ruta: ${SERVERKIT_HOME}\n"
  SERVERKIT_SUMMARY+="Grupos: $(id -nG "$SERVERKIT_USERNAME")\n"
  SERVERKIT_SUMMARY+="Contraseña: ${SERVERKIT_PASSWORD}\n"
  SERVERKIT_SUMMARY+="Guarde esta contraseña en un lugar seguro. No volverá a mostrarse después de este paso.\n"

  if [[ -f "$SSH_PUB" ]]; then
    SERVERKIT_SUMMARY+="\nClave pública (id_ed25519.pub):\n"
    SERVERKIT_SUMMARY+="$(cat "$SSH_PUB")\n"
  fi

  SERVERKIT_SUMMARY+="-------------------------------------------\n"
else
  echo "Error al crear el usuario '${SERVERKIT_USERNAME}'."
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="Error al crear el usuario '${SERVERKIT_USERNAME}'.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  exit 1
fi

# ---------------------------------------------------------------
# Mostrar resumen si se ejecuta directamente
# ---------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo
  echo "==========================================="
  echo "Creación del usuario administrativo"
  echo "==========================================="
  echo -e "$SERVERKIT_SUMMARY"
  echo
fi