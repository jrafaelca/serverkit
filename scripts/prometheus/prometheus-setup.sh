#!/usr/bin/env bash
set -euo pipefail

# ===============================================
# Instalación de Prometheus
# ===============================================
# Descarga e instala la última versión estable de Prometheus
# desde GitHub. Crea el usuario, directorios, configuración base
# y servicio systemd para ejecución en producción.
# ===============================================

[[ -z "${SERVERKIT_ENV_INITIALIZED:-}" ]] && source /opt/serverkit/scripts/common/loader.sh

prometheus_setup() {
  log_info "Iniciando instalación de Prometheus..."

  SERVICE="/etc/systemd/system/prometheus.service"
  BIN_PATH="/usr/local/bin/prometheus"
  DATA_DIR="/var/lib/prometheus"
  CONFIG_DIR="/etc/prometheus"
  OPT_DIR="/opt/prometheus"

  # --- Crear usuario prometheus ---
  if ! id -u prometheus >/dev/null 2>&1; then
    useradd --no-create-home --shell /usr/sbin/nologin --scripts prometheus
    log_info "Usuario 'prometheus' creado."
  else
    log_info "Usuario 'prometheus' ya existe, omitiendo creación."
  fi

  mkdir -p "$DATA_DIR" "$CONFIG_DIR" "$OPT_DIR/consoles" "$OPT_DIR/console_libraries"
  chown -R prometheus:prometheus "$DATA_DIR" "$CONFIG_DIR" "$OPT_DIR"

  # --- Descargar la última versión ---
  log_info "Descargando la última versión de Prometheus..."
  LATEST_URL=$(curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest \
    | grep browser_download_url \
    | grep linux-amd64 \
    | cut -d '"' -f 4)

  if [[ -z "$LATEST_URL" ]]; then
    log_error "No se pudo obtener la URL de descarga desde GitHub."
    exit 1
  fi

  VERSION=$(basename "$LATEST_URL" | grep -oP '(?<=prometheus-)[0-9.]+')
  log_info "Versión detectada: ${VERSION}"

  cd /usr/local/bin
  wget -q "$LATEST_URL" -O prometheus.tar.gz
  tar -xzf prometheus.tar.gz

  # --- Mover binarios ---
  mv prometheus-*/prometheus .
  mv prometheus-*/promtool .
  chmod +x "$BIN_PATH" /usr/local/bin/promtool

  # --- Copiar consolas ---
  cp -r prometheus-*/consoles "$OPT_DIR/"
  cp -r prometheus-*/console_libraries "$OPT_DIR/"

  # --- Limpieza ---
  rm -rf prometheus-* prometheus.tar.gz

  # --- Configuración base mínima ---
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

  chown -R prometheus:prometheus "$CONFIG_DIR"
  chmod 640 "${CONFIG_DIR}/prometheus.yml"

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

  sleep 3

  # --- Validación ---
  if systemctl is-active --quiet prometheus; then
    log_info "Prometheus iniciado correctamente."
  else
    log_error "El servicio prometheus no se inició correctamente."
  fi

  echo
  echo "✅ Prometheus instalado correctamente."

  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "==============================================="
    echo "Versión: ${VERSION}"
    echo "Configuración: ${CONFIG_DIR}/prometheus.yml"
    echo "Datos: ${DATA_DIR}"
    echo "Binarios: ${BIN_PATH}, /usr/local/bin/promtool"
    echo "Endpoint: http://$(hostname -I | awk '{print $1}'):9090"
    echo
    echo "Para limpiar el historial de shell:"
    echo "  history -c && history -w && rm -f ~/.bash_history"
    echo "==============================================="
  fi
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && prometheus_setup "$@"