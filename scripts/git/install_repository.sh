#!/usr/bin/env bash

# ===============================================
# Instalación de Repositorio SSH (Deploy Key)
# ===============================================
# Genera una Deploy Key para el usuario 'serverkit',
# configura el acceso SSH y clona el repositorio en
# /opt/<nombre_repo>.
#
# Uso:
#   /opt/serverkit/scripts/git/install-repo.sh \
#       URL=git@github.com:POSITION-CHILE/listener-node.git
#
# Nota:
#   - El parámetro PATH es opcional (por defecto /opt)
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

# ---------------------------------------------------------------
# Definir valores por defecto
# ---------------------------------------------------------------
PATH_DIR="${PATH_DIR:-/opt}"

# Verificar que PATH esté dentro de /opt
if [[ ! "$PATH_DIR" =~ ^/opt(/.*)?$ ]]; then
  echo "Error: el directorio de instalación debe estar dentro de /opt/"
  echo "Ruta recibida: ${PATH_DIR}"
  echo "Ejemplo válido: PATH=/opt"
  exit 1
fi

# ---------------------------------------------------------------
# Validaciones iniciales
# ---------------------------------------------------------------
if [[ -z "$URL" ]]; then
  echo "Error: debes proporcionar la URL del repositorio."
  echo "Ejemplo: $0 URL=git@github.com:ORG/REPO.git"
  exit 1
fi

if ! id "$APP_USER" &>/dev/null; then
  echo "Error: el usuario '${APP_USER}' no existe. Ejecuta primero setup-user.sh."
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
REPO_PATH_SHORT=$(echo "$URL" | cut -d':' -f2)

# Crear directorio base con permisos apropiados
if [[ ! -d "$PATH_DIR" ]]; then
  echo "Creando ruta base ${PATH_DIR}..."
  mkdir -p "$PATH_DIR"
  chown -R "$APP_USER":"$APP_USER" "$PATH_DIR"
  chmod 755 "$PATH_DIR"
fi

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