#!/usr/bin/env bash
set -euo pipefail

# ===============================================
# Instalación de Prometheus
# ===============================================
# Descarga e instala la última versión estable de Prometheus
# desde GitHub. Crea el usuario, directorios, configuración base
# y servicio systemd para ejecución en producción.
# Compatible con re-ejecuciones
# ===============================================

[[ -z "${SERVERKIT_ENV_INITIALIZED:-}" ]] && source /opt/serverkit/scripts/common/loader.sh

prometheus_setup() {
  log_info "Iniciando instalación de Prometheus..."

  local SERVICE="/etc/systemd/system/prometheus.service"
  local BIN_PATH="/usr/local/bin/prometheus"
  local BIN_TOOL="/usr/local/bin/promtool"
  local DATA_DIR="/var/lib/prometheus"
  local CONFIG_DIR="/etc/prometheus"
  local OPT_DIR="/opt/prometheus"

  # --- Crear usuario prometheus ---
  if ! id -u prometheus >/dev/null 2>&1; then
    useradd --no-create-home --shell /usr/sbin/nologin --system prometheus
    log_info "Usuario 'prometheus' creado."
  else
    log_info "Usuario 'prometheus' ya existe, omitiendo creación."
  fi

  mkdir -p "$DATA_DIR" "$CONFIG_DIR" "$OPT_DIR/consoles" "$OPT_DIR/console_libraries"
  chown -R prometheus:prometheus "$DATA_DIR" "$CONFIG_DIR" "$OPT_DIR"

  # --- Descargar la última versión ---
  log_info "Descargando la última versión de Prometheus..."
  local LATEST_URL
  LATEST_URL=$(curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest \
    | grep browser_download_url \
    | grep linux-amd64 \
    | cut -d '"' -f 4)

  if [[ -z "$LATEST_URL" ]]; then
    log_error "No se pudo obtener la URL de descarga desde GitHub."
    exit 1
  fi

  local VERSION
  VERSION=$(basename "$LATEST_URL" | grep -oP '(?<=prometheus-)[0-9.]+')
  log_info "Versión detectada: ${VERSION}"

  cd /usr/local/bin

  # --- Descarga y extracción ---
  wget -q "$LATEST_URL" -O prometheus.tar.gz
  tar -xzf prometheus.tar.gz

  # --- Mover binarios ---
  mv -f prometheus-*/prometheus "$BIN_PATH"
  mv -f prometheus-*/promtool "$BIN_TOOL"
  chmod +x "$BIN_PATH" "$BIN_TOOL"

  # --- Copiar consolas ---
  cp -r prometheus-*/consoles "$OPT_DIR/" 2>/dev/null || true
  cp -r prometheus-*/console_libraries "$OPT_DIR/" 2>/dev/null || true

  # --- Limpieza temporal ---
  rm -rf prometheus-* prometheus.tar.gz

  # --- Crear configuración base si no existe ---
  if [[ ! -f "${CONFIG_DIR}/prometheus.yml" ]]; then
    log_info "Creando configuración base..."
    cat > "${CONFIG_DIR}/prometheus.yml" <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF
  else
    log_info "Archivo de configuración existente, omitiendo creación."
  fi

  chown -R prometheus:prometheus "$CONFIG_DIR"
  find "$CONFIG_DIR" -type f -name '*.yml' -exec chmod 640 {} \;
  find "$CONFIG_DIR" -type d -exec chmod 750 {} \;

  # --- Crear servicio systemd ---
  log_info "Creando servicio systemd..."
  cat > "$SERVICE" <<EOF
[Unit]
Description=Prometheus Monitoring Service
Documentation=https://prometheus.io/
After=network-online.target
Wants=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=/var/lib/prometheus \\
  --web.console.templates=/opt/prometheus/consoles \\
  --web.console.libraries=/opt/prometheus/console_libraries \\
  --web.listen-address=0.0.0.0:9090

Restart=always
RestartSec=5s
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

  # --- Habilitar e iniciar servicio ---
  log_info "Habilitando e iniciando Prometheus..."
  systemctl daemon-reload
  systemctl enable --now prometheus

  sleep 2

  # --- Validación de estado ---
  if systemctl is-active --quiet prometheus; then
    log_info "✅ Prometheus iniciado correctamente."
  else
    log_error "⚠️  El servicio prometheus no se inició correctamente. Revisa los logs con:"
    echo "   journalctl -u prometheus -n 30 -xe"
  fi

  echo
  echo "==============================================="
  echo " Prometheus instalado correctamente "
  echo "==============================================="
  echo "Versión       : ${VERSION}"
  echo "Configuración : ${CONFIG_DIR}/prometheus.yml"
  echo "Datos         : ${DATA_DIR}"
  echo "Binarios      : ${BIN_PATH}, ${BIN_TOOL}"
  echo "Endpoint      : http://$(hostname -I | awk '{print $1}'):9090"
  echo "==============================================="
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && prometheus_setup "$@"