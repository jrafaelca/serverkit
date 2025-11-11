#!/usr/bin/env bash

# ===============================================
# Desinstalación de Repositorio SSH
# ===============================================
# Elimina la deploy key, el alias SSH y la carpeta
# del proyecto basándose en su ruta local.
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Desinstalación de repositorio SSH..."

APP_USER="serverkit"
APP_HOME="/home/${APP_USER}"
SSH_DIR="${APP_HOME}/.ssh"
SSH_CONFIG="${SSH_DIR}/config"

# ---------------------------------------------------------------
# Parseo de argumentos (permite ejecución no interactiva)
# ---------------------------------------------------------------
PROJECT_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)
      PROJECT_PATH="$2"
      shift 2
      ;;
    -h|--help)
      echo "Uso: $0 --path /opt/apps/<repo>"
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

if [[ -z "$PROJECT_PATH" ]]; then
  read -rp "Ingresa la ruta completa del proyecto a eliminar (ej: /opt/apps/listener-node): " PROJECT_PATH
fi

if [[ -z "$PROJECT_PATH" || ! -d "$PROJECT_PATH" ]]; then
  echo "Error: la ruta '${PROJECT_PATH}' no es válida o no existe."
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Repositorio SSH]\n"
  SERVERKIT_SUMMARY+="Error: ruta no válida (${PROJECT_PATH}).\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  [[ "${BASH_SOURCE[0]}" == "${0}" ]] && echo -e "$SERVERKIT_SUMMARY"
  exit 1
fi

if [[ ! -d "$PROJECT_PATH/.git" ]]; then
  echo "Error: no se encontró un repositorio Git en ${PROJECT_PATH}."
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Repositorio SSH]\n"
  SERVERKIT_SUMMARY+="Error: no se encontró repositorio Git en ${PROJECT_PATH}.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  [[ "${BASH_SOURCE[0]}" == "${0}" ]] && echo -e "$SERVERKIT_SUMMARY"
  exit 1
fi

# ---------------------------------------------------------------
# Obtener información del repositorio
# ---------------------------------------------------------------
REPO_URL=$(sudo -u "$APP_USER" git -C "$PROJECT_PATH" remote get-url origin 2>/dev/null || true)
REPO_NAME=$(basename -s .git "$REPO_URL")
KEY_PATH="${SSH_DIR}/deploy_${REPO_NAME}"

echo
echo "Repositorio detectado:"
echo "  Nombre: ${REPO_NAME}"
echo "  URL remota: ${REPO_URL:-desconocida}"
echo "  Ruta local: ${PROJECT_PATH}"
echo

# ---------------------------------------------------------------
# Confirmación manual (si hay TTY)
# ---------------------------------------------------------------
if [[ -t 0 ]]; then
  read -rp "¿Deseas proceder con la desinstalación completa? (y/n): " CONFIRM
  if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Operación cancelada por el usuario."
    SERVERKIT_SUMMARY+="-------------------------------------------\n"
    SERVERKIT_SUMMARY+="[Repositorio SSH]\n"
    SERVERKIT_SUMMARY+="Operación cancelada por el usuario.\n"
    SERVERKIT_SUMMARY+="-------------------------------------------\n"
    [[ "${BASH_SOURCE[0]}" == "${0}" ]] && echo -e "$SERVERKIT_SUMMARY"
    exit 0
  fi
else
  echo "Modo no interactivo detectado: eliminación automática en curso..."
fi

# ---------------------------------------------------------------
# Eliminación de claves SSH
# ---------------------------------------------------------------
if [[ -f "$KEY_PATH" || -f "${KEY_PATH}.pub" ]]; then
  echo "Eliminando claves SSH asociadas..."
  rm -f "${KEY_PATH}" "${KEY_PATH}.pub" 2>/dev/null || true
else
  echo "No se encontraron claves SSH asociadas (${KEY_PATH})."
fi

# ---------------------------------------------------------------
# Limpieza del alias en ~/.ssh/config
# ---------------------------------------------------------------
if [[ -f "$SSH_CONFIG" ]]; then
  if grep -q "Host github.com-${REPO_NAME}" "$SSH_CONFIG"; then
    echo "Eliminando alias SSH de ${SSH_CONFIG}..."
    awk -v repo="github.com-${REPO_NAME}" '
      BEGIN { skip=0 }
      /^Host / { skip=($2==repo) }
      !skip
    ' "$SSH_CONFIG" > "${SSH_CONFIG}.tmp" && mv "${SSH_CONFIG}.tmp" "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
  else
    echo "No se encontró alias SSH para ${REPO_NAME}."
  fi
fi

# ---------------------------------------------------------------
# Eliminación del directorio del proyecto
# ---------------------------------------------------------------
if [[ -d "$PROJECT_PATH" ]]; then
  echo "Eliminando directorio del proyecto..."
  rm -rf "$PROJECT_PATH"
else
  echo "No se encontró el directorio ${PROJECT_PATH}."
fi

echo "Desinstalación completada para '${REPO_NAME}'."

# ---------------------------------------------------------------
# Registrar resumen
# ---------------------------------------------------------------
SERVERKIT_SUMMARY+="-------------------------------------------\n"
SERVERKIT_SUMMARY+="[Repositorio SSH]\n"
SERVERKIT_SUMMARY+="Nombre: ${REPO_NAME}\n"
SERVERKIT_SUMMARY+="Ruta eliminada: ${PROJECT_PATH}\n"
SERVERKIT_SUMMARY+="Usuario: ${APP_USER}\n"
SERVERKIT_SUMMARY+="Archivos SSH removidos: ${KEY_PATH} y ${KEY_PATH}.pub\n"
SERVERKIT_SUMMARY+="Alias SSH removido (si existía): github.com-${REPO_NAME}\n"
SERVERKIT_SUMMARY+="Estado: desinstalado correctamente.\n"
SERVERKIT_SUMMARY+="-------------------------------------------\n"

# Mostrar resumen si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo -e "$SERVERKIT_SUMMARY"
fi