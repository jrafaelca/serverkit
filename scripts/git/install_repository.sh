#!/usr/bin/env bash

# ===============================================
# Instalación de Repositorio SSH
# ===============================================
# Genera una deploy key para el usuario 'serverkit',
# configura el acceso SSH y clona el repositorio en
# una ruta definida por el usuario.
# ===============================================

[[ -z "${SERVERKIT_ENV_INITIALIZED:-}" ]] && source /opt/serverkit/scripts/common/loader.sh

install_repository() {
  local APP_USER="serverkit"
  local APP_HOME="/home/${APP_USER}"
  local SSH_DIR="${APP_HOME}/.ssh"

  log_info "📦 Instalación de repositorio mediante Deploy Key SSH"

  # ---  usuario ---
  if ! id "$APP_USER" &>/dev/null; then
    log_error "❌ El usuario '${APP_USER}' no existe."
    return 1
  fi

  # --- Solicitar URL ---
  read -rp "👉 Ingresa la URL del repositorio (ej: git@github.com:POSITION-CHILE/listener-node.git): " REPO_URL
  [[ -z "$REPO_URL" ]] && { log_error "❌ URL no válida."; return 1; }

  # --- Extraer nombre del repositorio ---
  local REPO_NAME
  REPO_NAME=$(basename -s .git "$REPO_URL")

  # --- Solicitar ruta base ---
  read -rp "📁 Ruta base de instalación (por defecto: /opt/apps): " BASE_PATH
  BASE_PATH="${BASE_PATH:-/opt/apps}"

  local DEST_DIR="${BASE_PATH}/${REPO_NAME}"
  local KEY_PATH="${SSH_DIR}/deploy_${REPO_NAME}"
  local SSH_CONFIG="${SSH_DIR}/config"

  # --- Generar clave SSH ---
  log_info "🗝️  Generando clave SSH..."
  sudo -u "$APP_USER" mkdir -p "$SSH_DIR"
  sudo -u "$APP_USER" chmod 700 "$SSH_DIR"
  sudo -u "$APP_USER" ssh-keygen -t ed25519 -f "$KEY_PATH" -N '' -C "${APP_USER}@$(hostname)" >/dev/null

  log_info "📄 Clave pública generada. Agrégala como 'Deploy Key' con permisos de lectura:"
  echo "------------------------------------------------------------"
  cat "${KEY_PATH}.pub"
  echo "------------------------------------------------------------"
  echo ""

  # --- Confirmar paso ---
  read -rp "¿Ya agregaste la clave en el repositorio? (y/n): " CONFIRM
  if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    log_warn "⚠️ Operación cancelada por el usuario."
    log_info "🧹 Eliminando clave SSH generada..."
    rm -f "${KEY_PATH}" "${KEY_PATH}.pub"
    return 0
  fi

  # --- Configurar alias SSH (sin problemas de permisos) ---
  log_info "⚙️  Configurando alias SSH..."
  sudo -u "$APP_USER" bash -c "mkdir -p '${SSH_DIR}' && chmod 700 '${SSH_DIR}'"
  sudo -u "$APP_USER" bash -c "echo 'Host github.com-${REPO_NAME}
    HostName github.com
    User git
    IdentityFile ${KEY_PATH}
    IdentitiesOnly yes
' >> '${SSH_CONFIG}'"
  sudo -u "$APP_USER" bash -c "chmod 600 '${SSH_CONFIG}'"

  # --- Clonar repositorio ---
  log_info "📥 Clonando el repositorio..."
  local REPO_PATH
  REPO_PATH=$(echo "$REPO_URL" | cut -d':' -f2)
  sudo -u "$APP_USER" mkdir -p "$BASE_PATH"

  if [[ -d "$DEST_DIR/.git" ]]; then
    log_warn "⚠️ El repositorio ya existe en ${DEST_DIR}. Omitiendo clonación."
  else
    sudo -u "$APP_USER" git clone "git@github.com-${REPO_NAME}:${REPO_PATH}" "$DEST_DIR"
  fi

  log_info "✅ Repositorio '${REPO_NAME}' instalado en ${DEST_DIR}"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && install_repository "$@"