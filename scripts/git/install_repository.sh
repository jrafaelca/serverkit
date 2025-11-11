#!/usr/bin/env bash

# ===============================================
# Instalación de Repositorio SSH
# ===============================================
# Genera una Deploy Key para el usuario 'serverkit',
# configura el acceso SSH y clona el repositorio en
# una ruta definida (manual o por argumentos).
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Configurando instalación de repositorio mediante Deploy Key SSH..."

APP_USER="serverkit"
APP_HOME="/home/${APP_USER}"
SSH_DIR="${APP_HOME}/.ssh"

# ---------------------------------------------------------------
# Parseo de argumentos (permite ejecución no interactiva)
# ---------------------------------------------------------------
REPO_URL=""
BASE_PATH="/opt/apps"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO_URL="$2"
      shift 2
      ;;
    --path)
      BASE_PATH="$2"
      shift 2
      ;;
    -h|--help)
      echo "Uso: $0 --repo <git@github.com:org/repo.git> [--path /opt/apps]"
      exit 0
      ;;
    *)
      echo "Opción desconocida: $1"
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------
# Validaciones iniciales
# ---------------------------------------------------------------
if ! id "$APP_USER" &>/dev/null; then
  echo "Error: el usuario '${APP_USER}' no existe."
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Repositorio SSH]\n"
  SERVERKIT_SUMMARY+="Error: el usuario '${APP_USER}' no existe.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  [[ "${BASH_SOURCE[0]}" == "${0}" ]] && echo -e "$SERVERKIT_SUMMARY"
  exit 1
fi

if [[ -z "$REPO_URL" ]]; then
  read -rp "Ingresa la URL del repositorio (ej: git@github.com:POSITION-CHILE/listener-node.git): " REPO_URL
fi

if [[ -z "$REPO_URL" ]]; then
  echo "Error: no se proporcionó una URL válida."
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Repositorio SSH]\n"
  SERVERKIT_SUMMARY+="Error: no se proporcionó una URL válida.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  [[ "${BASH_SOURCE[0]}" == "${0}" ]] && echo -e "$SERVERKIT_SUMMARY"
  exit 1
fi

REPO_NAME=$(basename -s .git "$REPO_URL")
DEST_DIR="${BASE_PATH}/${REPO_NAME}"
KEY_PATH="${SSH_DIR}/deploy_${REPO_NAME}"
SSH_CONFIG="${SSH_DIR}/config"

# ---------------------------------------------------------------
# Generación de claves SSH
# ---------------------------------------------------------------
echo "Generando clave SSH para el repositorio..."
sudo -u "$APP_USER" mkdir -p "$SSH_DIR"
sudo -u "$APP_USER" chmod 700 "$SSH_DIR"
sudo -u "$APP_USER" ssh-keygen -t ed25519 -f "$KEY_PATH" -N '' -C "${APP_USER}@$(hostname)" >/dev/null

echo
echo "Clave pública generada. Agrega esta Deploy Key con permisos de lectura:"
echo "------------------------------------------------------------"
cat "${KEY_PATH}.pub"
echo "------------------------------------------------------------"

# Si no está en modo no interactivo, pedir confirmación
if [[ -t 0 ]]; then
  read -rp "¿Ya agregaste la clave en el repositorio? (y/n): " CONFIRM
  if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Operación cancelada. Eliminando claves generadas..."
    rm -f "${KEY_PATH}" "${KEY_PATH}.pub"
    SERVERKIT_SUMMARY+="-------------------------------------------\n"
    SERVERKIT_SUMMARY+="[Repositorio SSH]\n"
    SERVERKIT_SUMMARY+="Instalación cancelada por el usuario.\n"
    SERVERKIT_SUMMARY+="-------------------------------------------\n"
    [[ "${BASH_SOURCE[0]}" == "${0}" ]] && echo -e "$SERVERKIT_SUMMARY"
    exit 0
  fi
else
  echo "Modo no interactivo detectado: se asume que la Deploy Key ya está configurada."
fi

# ---------------------------------------------------------------
# Configurar alias SSH
# ---------------------------------------------------------------
echo "Configurando alias SSH..."
sudo -u "$APP_USER" bash -c "echo 'Host github.com-${REPO_NAME}
    HostName github.com
    User git
    IdentityFile ${KEY_PATH}
    IdentitiesOnly yes
' >> '${SSH_CONFIG}'"
sudo -u "$APP_USER" bash -c "chmod 600 '${SSH_CONFIG}'"

# ---------------------------------------------------------------
# Clonación del repositorio
# ---------------------------------------------------------------
echo "Clonando el repositorio..."
REPO_PATH=$(echo "$REPO_URL" | cut -d':' -f2)
sudo -u "$APP_USER" mkdir -p "$BASE_PATH"

if [[ -d "$DEST_DIR/.git" ]]; then
  echo "El repositorio ya existe en ${DEST_DIR}. Omitiendo clonación."
else
  sudo -u "$APP_USER" git clone "git@github.com-${REPO_NAME}:${REPO_PATH}" "$DEST_DIR"
fi

echo "Repositorio '${REPO_NAME}' instalado correctamente en ${DEST_DIR}."

# ---------------------------------------------------------------
# Registrar resumen
# ---------------------------------------------------------------
SERVERKIT_SUMMARY+="-------------------------------------------\n"
SERVERKIT_SUMMARY+="[Repositorio SSH]\n"
SERVERKIT_SUMMARY+="Nombre del repositorio: ${REPO_NAME}\n"
SERVERKIT_SUMMARY+="Ruta destino: ${DEST_DIR}\n"
SERVERKIT_SUMMARY+="Usuario: ${APP_USER}\n"
SERVERKIT_SUMMARY+="Clave SSH: ${KEY_PATH}\n"
SERVERKIT_SUMMARY+="Alias SSH: github.com-${REPO_NAME}\n"
SERVERKIT_SUMMARY+="Clave pública:\n$(cat "${KEY_PATH}.pub")\n"
SERVERKIT_SUMMARY+="-------------------------------------------\n"

# Mostrar resumen si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo -e "$SERVERKIT_SUMMARY"
fi