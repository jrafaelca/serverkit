#!/usr/bin/env bash
set -euo pipefail

# ===============================================
# Instalación de PgBouncer Exporter
# ===============================================
# Crea usuario "exporter" en PgBouncer y configura
# el servicio Prometheus pgbouncer_exporter.
# ===============================================

[[ -z "${SERVERKIT_ENV_INITIALIZED:-}" ]] && source /opt/serverkit/scripts/common/loader.sh

pgbouncer_exporter_setup() {
  log_info "Instalando PgBouncer Exporter..."

  USERLIST="/etc/pgbouncer/userlist.txt"
  SERVICE="/etc/systemd/system/pgbouncer-exporter.service"
  BIN_PATH="/usr/local/bin/pgbouncer_exporter"

  # --- Verifica que PgBouncer exista ---
  if ! command -v pgbouncer >/dev/null 2>&1; then
    log_error "PgBouncer no está instalado. Instálalo antes de continuar."
    exit 1
  fi

  # --- Usuario exporter ---
  EXPORTER_USER="exporter"
  EXPORTER_PASS="$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-18)"
  EXPORTER_MD5_HASH="md5$(printf '%s' "${EXPORTER_PASS}${EXPORTER_USER}" | md5sum | awk '{print $1}')"

  echo "\"${EXPORTER_USER}\" \"${EXPORTER_MD5_HASH}\"" >> "$USERLIST"

  # --- Descargar la última versión ---
  log_info "Descargando la última versión de pgbouncer_exporter..."
  LATEST_URL=$(curl -s https://api.github.com/repos/prometheus-community/pgbouncer_exporter/releases/latest \
    | grep browser_download_url \
    | grep linux-amd64 \
    | cut -d '"' -f 4)

  cd /usr/local/bin
  wget -q "$LATEST_URL" -O pgbouncer_exporter.tar.gz
  tar -xzf pgbouncer_exporter.tar.gz
  mv pgbouncer_exporter-*/pgbouncer_exporter .
  chmod +x "$BIN_PATH"
  rm -rf pgbouncer_exporter-* pgbouncer_exporter.tar.gz

  # --- Crear servicio systemd ---
  cat > "$SERVICE" <<EOF
[Unit]
Description=PgBouncer Prometheus Exporter
After=network.target pgbouncer.service

[Service]
User=pgbouncer
ExecStart=/usr/local/bin/pgbouncer_exporter --web.listen-address=":9187" --pgBouncer.connectionString="postgres://${EXPORTER_USER}:${EXPORTER_PASS}@$(hostname -I | awk '{print $1}'):6432/pgbouncer?sslmode=require"
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

  # --- Iniciar y habilitar ---
  systemctl daemon-reload
  systemctl enable --now pgbouncer-exporter

  sleep 3

  # --- Validación ---
  if systemctl is-active --quiet pgbouncer-exporter; then
    log_info "PgBouncer Exporter iniciado correctamente."
  else
    log_error "El servicio pgbouncer-exporter no se inició correctamente."
  fi

  echo
  echo "PgBouncer Exporter instalado correctamente."

  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "==============================================="
    echo "Usuario : ${EXPORTER_USER}"
    echo "Contraseña : ${EXPORTER_PASS}"
    echo "Endpoint métricas : http://localhost:9187/metrics"
    echo
    echo "Para limpiar del historial los datos sensibles, ejecuta (una sola línea):"
    echo "  history -c && history -w && rm -f ~/.bash_history"
    echo "==========================================="
  fi
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && pgbouncer_exporter_setup "$@"