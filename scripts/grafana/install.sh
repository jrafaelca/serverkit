#!/usr/bin/env bash
set -e

# ===============================================
# Instalación de Grafana OSS (Open Source)
# ===============================================
# Instala Grafana OSS desde el repositorio oficial
# de Grafana Labs en Debian/Ubuntu. Crea el usuario
# administrativo 'serverkit' con una contraseña
# aleatoria no persistente y configura el servicio
# systemd incluido.
# ===============================================

[[ -z "${SERVERKIT_ENV_INITIALIZED:-}" ]] && source /opt/serverkit/scripts/common/loader.sh

install_grafana() {
  log_info "Iniciando instalación de Grafana OSS..."

  local CONFIG_FILE="/etc/grafana/grafana.ini"
  local ADMIN_USER="serverkit"
  local ADMIN_PASS
  local GPG_KEYRING="/etc/apt/keyrings/grafana.gpg"
  local REPO_LIST="/etc/apt/sources.list.d/grafana.list"

  # --- Instalar dependencias base ---
  log_info "Instalando dependencias base..."
  apt-get update -y
  apt-get install -y apt-transport-https software-properties-common wget gpg

  # --- Agregar repositorio oficial de Grafana Labs ---
  log_info "Agregando repositorio de Grafana..."
  mkdir -p /etc/apt/keyrings/

  if [[ ! -f "$GPG_KEYRING" ]]; then
    wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | tee "$GPG_KEYRING" >/dev/null
    echo "deb [signed-by=${GPG_KEYRING}] https://apt.grafana.com stable main" > "$REPO_LIST"
  else
    log_info "Repositorio de Grafana ya configurado, omitiendo."
  fi

  # --- Actualizar repositorios e instalar Grafana OSS ---
  apt-get update -y
  if ! dpkg -l | grep -q grafana; then
    log_info "Instalando Grafana OSS..."
    apt-get install -y grafana
  else
    log_info "Grafana OSS ya se encuentra instalado. Omitiendo."
  fi

  # --- Generar contraseña efímera (no persistente) ---
  ADMIN_PASS=$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-16)
  log_info "Contraseña aleatoria generada para '${ADMIN_USER}'."

  # --- Configuración básica ---
  log_info "Aplicando configuración base..."
  if [[ -f "$CONFIG_FILE" ]]; then
    sed -i "s/^;http_port = .*/http_port = 3000/" "$CONFIG_FILE"
    sed -i "s/^;allow_sign_up = .*/allow_sign_up = false/" "$CONFIG_FILE"
    sed -i "s/^;admin_user = .*/admin_user = ${ADMIN_USER}/" "$CONFIG_FILE"
    sed -i "s/^;admin_password = .*/admin_password = ${ADMIN_PASS}/" "$CONFIG_FILE"
  else
    cat > "$CONFIG_FILE" <<EOF
[server]
http_port = 3000

[security]
allow_sign_up = false
admin_user = ${ADMIN_USER}
admin_password = ${ADMIN_PASS}
EOF
  fi

  chown -R grafana:grafana /etc/grafana
  chmod 640 "$CONFIG_FILE"

  # --- Habilitar e iniciar Grafana ---
  log_info "Habilitando y iniciando servicio grafana-server..."
  systemctl daemon-reload
  systemctl enable --now grafana-server

  sleep 3

  # --- Validar estado ---
  if systemctl is-active --quiet grafana-server; then
    log_info "✅ Grafana OSS iniciado correctamente."
  else
    log_error "⚠️  El servicio grafana-server no se inició correctamente."
    echo "   journalctl -u grafana-server -n 30 -xe"
  fi

  echo
  echo "==============================================="
  echo " Grafana OSS instalado correctamente "
  echo "==============================================="
  echo "👤 Usuario admin : ${ADMIN_USER}"
  echo "🔑 Contraseña     : ${ADMIN_PASS}"
  echo "🌐 Puerto         : 3000"
  echo "📡 URL acceso     : http://$(hostname -I | awk '{print $1}'):3000"
  echo "==============================================="
  echo ""
  echo "⚠️  Guarda esta contraseña ahora. No se volverá a mostrar ni se guarda en disco."
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && install_grafana "$@"