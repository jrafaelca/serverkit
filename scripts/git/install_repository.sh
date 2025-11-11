#!/usr/bin/env bash

# ===============================================
# Instalación de Repositorio SSH (Deploy Key)
# ===============================================
# Genera una Deploy Key para el usuario 'serverkit',
# configura el acceso SSH y clona el repositorio en
# la ruta indicada.
#
# Uso:
#   /opt/serverkit/scripts/git/install-repo.sh \
#       URL=git@github.com:POSITION-CHILE/listener-node.git \
#       PATH=/opt/apps
#
# Nota:
#   - El parámetro PATH es opcional (por defecto /opt/apps)
#   - Si el repositorio ya existe, se omite la clonación
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Instalando repositorio mediante Deploy Key SSH..."

APP_USER="serverkit"
APP_HOME="/home/${APP_USER}"
SSH_DIR="${APP_HOME}/.ssh"

# ---------------------------------------------------------------
# Parseo de argumentos estilo KEY=VALUE
# ---------------------------------------------------------------
for arg in "$@"; do
  case "$arg" in
    URL=*)
      URL="${arg#URL=}"
      ;;
    PATH=*)
      PATH_DIR="${arg#PATH=}"
      ;;
    *)
      echo "Opción no reconocida: ${arg}"
      exit 1
      ;;
  esac
done

# Valor por defecto si no se define PATH
PATH_DIR="${PATH_DIR:-/opt/apps}"

# Validación básica
if [[ -z "$URL" ]]; then
  echo "Error: Debes proporcionar la URL del repositorio."
  echo "Ejemplo: $0 URL=git@github.com:ORG/REPO.git [PATH=/opt/apps]"
  exit 1
fi

# ---------------------------------------------------------------
# Preparar entorno base
# ---------------------------------------------------------------
REPO_NAME=$(basename -s .git "$URL")
DEST_DIR="${PATH_DIR}/${REPO_NAME}"
KEY_PATH="${SSH_DIR}/deploy_${REPO_NAME}"
SSH_CONFIG="${SSH_DIR}/config"

sudo -u "$APP_USER" mkdir -p "$SSH_DIR"
sudo -u "$APP_USER" chmod 700 "$SSH_DIR"

# ---------------------------------------------------------------
# Generar clave SSH (solo si no existe)
# ---------------------------------------------------------------
if [[ ! -f "$KEY_PATH" ]]; then
  echo "Generando clave SSH para el repositorio..."
  sudo -u "$APP_USER" ssh-keygen -t ed25519 -f "$KEY_PATH" -N '' -C "${APP_USER}@$(hostname)" >/dev/null
  echo
  echo "Clave pública generada. Agrega esta Deploy Key con permisos de lectura:"
  echo "------------------------------------------------------------"
  cat "${KEY_PATH}.pub"
  echo "------------------------------------------------------------"
  echo
  read -rp "Confirma cuando la Deploy Key haya sido agregada (ENTER para continuar)..."
else
  echo "Clave existente detectada: ${KEY_PATH}"
fi

# ---------------------------------------------------------------
# Configurar alias SSH
# ---------------------------------------------------------------
if ! grep -q "github.com-${REPO_NAME}" "$SSH_CONFIG" 2>/dev/null; then
  echo "Configurando alias SSH..."
  sudo -u "$APP_USER" bash -c "cat <<EOF >> '${SSH_CONFIG}'
Host github.com-${REPO_NAME}
    HostName github.com
    User git
    IdentityFile ${KEY_PATH}
    IdentitiesOnly yes
EOF"
  sudo -u "$APP_USER" chmod 600 "${SSH_CONFIG}"
else
  echo "Alias SSH ya existente para ${REPO_NAME}."
fi

# ---------------------------------------------------------------
# Clonación (solo si no existe)
# ---------------------------------------------------------------
sudo -u "$APP_USER" mkdir -p "$PATH_DIR"
REPO_PATH_SHORT=$(echo "$URL" | cut -d':' -f2)

if [[ -d "${DEST_DIR}/.git" ]]; then
  echo "El repositorio '${REPO_NAME}' ya existe en ${DEST_DIR}. Omitiendo clonación."
else
  echo "Clonando el repositorio..."
  sudo -u "$APP_USER" git clone "git@github.com-${REPO_NAME}:${REPO_PATH_SHORT}" "$DEST_DIR"
fi

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
SERVERKIT_SUMMARY+="-------------------------------------------\n"

# ---------------------------------------------------------------
# Mostrar resumen si se ejecuta directamente
# ---------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo
  echo -e "$SERVERKIT_SUMMARY"
fi