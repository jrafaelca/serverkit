#!/usr/bin/env bash

# ===============================================
# Desinstalación de Repositorio SSH
# ===============================================
# Elimina la Deploy Key, el alias SSH y el directorio
# del proyecto especificado.
#
# Ejemplo:
#   /opt/serverkit/scripts/git/uninstall-repo.sh \
#       PATH=/opt/apps/listener-node
#
# Nota:
#   - Si el repositorio no existe, el proceso informa y finaliza.
#   - Solicita confirmación manual si hay TTY disponible.
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Desinstalación de repositorio SSH..."

APP_USER="serverkit"
APP_HOME="/home/${APP_USER}"
SSH_DIR="${APP_HOME}/.ssh"
SSH_CONFIG="${SSH_DIR}/config"

# ---------------------------------------------------------------
# Parseo de argumentos estilo KEY=VALUE
# ---------------------------------------------------------------
for arg in "$@"; do
  case "$arg" in
    PATH=*)
      PROJECT_PATH="${arg#PATH=}"
      ;;
    *)
      echo "Opción no reconocida: ${arg}"
      exit 1
      ;;
  esac
done

# Validación básica
if [[ -z "$PROJECT_PATH" ]]; then
  echo "Error: debes indicar la ruta del proyecto a eliminar."
  echo "Ejemplo: $0 PATH=/opt/apps/listener-node"
  exit 1
fi

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

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "El directorio '${PROJECT_PATH}' no existe. No hay nada que eliminar."
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Repositorio SSH]\n"
  SERVERKIT_SUMMARY+="Ruta inexistente: ${PROJECT_PATH}\n"
  SERVERKIT_SUMMARY+="Estado: sin cambios.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  [[ "${BASH_SOURCE[0]}" == "${0}" ]] && echo -e "$SERVERKIT_SUMMARY"
  exit 0
fi

if [[ ! -d "$PROJECT_PATH/.git" ]]; then
  echo "Advertencia: no se encontró un repositorio Git en ${PROJECT_PATH}."
  echo "El directorio será eliminado de todas formas."
fi

# ---------------------------------------------------------------
# Detección de información del repositorio
# ---------------------------------------------------------------
REPO_URL=$(sudo -u "$APP_USER" git -C "$PROJECT_PATH" remote get-url origin 2>/dev/null || true)
REPO_NAME=$(basename -s .git "$REPO_URL")
REPO_NAME=${REPO_NAME:-$(basename "$PROJECT_PATH")}
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
echo "Eliminando directorio del proyecto..."
rm -rf "$PROJECT_PATH"

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