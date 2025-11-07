#!/usr/bin/env bash

# ===============================================
# Desinstalación de Repositorio SSH
# ===============================================
# Elimina la deploy key, el alias SSH y la carpeta
# del proyecto basándose en su ruta local.
# ===============================================

[[ -z "${SERVERKIT_ENV_INITIALIZED:-}" ]] && source /opt/serverkit/scripts/common/loader.sh

uninstall_repository() {
  local APP_USER="serverkit"
  local APP_HOME="/home/${APP_USER}"
  local SSH_DIR="${APP_HOME}/.ssh"
  local SSH_CONFIG="${SSH_DIR}/config"

  log_info "🧹 Desinstalación de repositorio SSH"

  if ! id "$APP_USER" &>/dev/null; then
    log_error "❌ El usuario '${APP_USER}' no existe."
    return 1
  fi

  # --- Solicita la ruta del proyecto ---
  read -rp "📁 Ingresa la ruta completa del proyecto a eliminar (ej: /opt/apps/node/listener-node): " PROJECT_PATH
  [[ -z "$PROJECT_PATH" ]] && { log_error "❌ Ruta no válida."; return 1; }

  if [[ ! -d "$PROJECT_PATH/.git" ]]; then
    log_error "❌ No se encontró un repositorio Git en ${PROJECT_PATH}."
    return 1
  fi

  # --- Obtiene información del repositorio ---
  local REPO_URL
  REPO_URL=$(sudo -u "$APP_USER" git -C "$PROJECT_PATH" remote get-url origin 2>/dev/null || true)
  if [[ -z "$REPO_URL" ]]; then
    log_error "❌ No se pudo obtener la URL remota del repositorio."
    return 1
  fi

  # Extrae nombre del repositorio (sin .git)
  local REPO_NAME
  REPO_NAME=$(basename -s .git "$REPO_URL")

  local KEY_PATH="${SSH_DIR}/deploy_${REPO_NAME}"

  log_info "📦 Repositorio detectado:"
  log_info "   🔹 Nombre: ${REPO_NAME}"
  log_info "   🔹 URL remota: ${REPO_URL}"
  log_info "   🔹 Ruta local: ${PROJECT_PATH}"
  echo ""

  # --- Confirmación antes de eliminar ---
  read -rp "⚠️ ¿Deseas proceder con la desinstalación completa? (y/n): " CONFIRM
  if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    log_warn "🚫 Operación cancelada por el usuario."
    return 0
  fi

  # --- Elimina claves SSH asociadas ---
  log_info "🗝️  Eliminando claves SSH asociadas..."
  rm -f "${KEY_PATH}" "${KEY_PATH}.pub" 2>/dev/null || true

  # --- Limpia el alias del archivo SSH config ---
  if [[ -f "$SSH_CONFIG" ]]; then
    if grep -q "Host github.com-${REPO_NAME}" "$SSH_CONFIG"; then
      log_info "⚙️  Removiendo alias del archivo SSH config..."
      awk -v repo="github.com-${REPO_NAME}" '
        BEGIN { skip=0 }
        /^Host / { skip=($2==repo) }
        !skip
      ' "$SSH_CONFIG" > "${SSH_CONFIG}.tmp" && mv "${SSH_CONFIG}.tmp" "$SSH_CONFIG"
      chmod 600 "$SSH_CONFIG"
    else
      log_warn "⚠️ No se encontró alias SSH para ${REPO_NAME}."
    fi
  fi

  # --- Elimina el directorio del proyecto ---
  if [[ -d "$PROJECT_PATH" ]]; then
    log_info "🗑️  Eliminando directorio del proyecto..."
    rm -rf "$PROJECT_PATH"
  else
    log_warn "⚠️ No se encontró el directorio ${PROJECT_PATH}."
  fi

  log_info "✅ Desinstalación completada para '${REPO_NAME}'."
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && uninstall_repository "$@"