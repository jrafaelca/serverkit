#!/usr/bin/env bash

# ===============================================
# Instalación de Prometheus
# ===============================================
# Descarga e instala la última versión estable de Prometheus
# desde GitHub. Crea el usuario, directorios, configuración base
# y servicio systemd para ejecución en producción.
# Compatible con re-ejecuciones.
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Iniciando instalación de Prometheus..."

SERVICE="/etc/systemd/system/prometheus.service"
BIN_PATH="/usr/local/bin/prometheus"
BIN_TOOL="/usr/local/bin/promtool"
DATA_DIR="/var/lib/prometheus"
CONFIG_DIR="/etc/prometheus"
OPT_DIR="/opt/prometheus"

# ---------------------------------------------------------------
# Crear usuario prometheus
# ---------------------------------------------------------------
if ! id -u prometheus >/dev/null 2>&1; then
  useradd --no-create-home --shell /usr/sbin/nologin --system prometheus
  echo "Usuario 'prometheus' creado."
else
  echo "Usuario 'prometheus' ya existe, omitiendo creación."
fi

mkdir -p "$DATA_DIR" "$CONFIG_DIR" "$OPT_DIR/consoles" "$OPT_DIR/console_libraries"
chown -R prometheus:prometheus "$DATA_DIR" "$CONFIG_DIR" "$OPT_DIR"

# ---------------------------------------------------------------
# Descargar última versión
# ---------------------------------------------------------------
echo "Descargando la última versión estable desde GitHub..."
LATEST_URL=$(curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest \
  | grep browser_download_url \
  | grep linux-amd64 \
  | cut -d '"' -f 4)

if [[ -z "$LATEST_URL" ]]; then
  echo "Error: No se pudo obtener la URL de descarga desde GitHub."
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Prometheus]\n"
  SERVERKIT_SUMMARY+="Error: No se pudo obtener la versión desde GitHub.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  exit 1
fi

VERSION=$(basename "$LATEST_URL" | grep -oP '(?<=prometheus-)[0-9.]+')
echo "Versión detectada: ${VERSION}"

cd /usr/local/bin
wget -q "$LATEST_URL" -O prometheus.tar.gz
tar -xzf prometheus.tar.gz >/dev/null 2>&1

mv -f prometheus-*/prometheus "$BIN_PATH"
mv -f prometheus-*/promtool "$BIN_TOOL"
chmod +x "$BIN_PATH" "$BIN_TOOL"

cp -r prometheus-*/consoles "$OPT_DIR/" 2>/dev/null || true
cp -r prometheus-*/console_libraries "$OPT_DIR/" 2>/dev/null || true

rm -rf prometheus-* prometheus.tar.gz

# ---------------------------------------------------------------
# Crear configuración base si no existe
# ---------------------------------------------------------------
if [[ ! -f "${CONFIG_DIR}/prometheus.yml" ]]; then
  echo "Creando configuración base..."
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
  echo "Archivo de configuración existente, omitiendo creación."
fi

chown -R prometheus:prometheus "$CONFIG_DIR"
find "$CONFIG_DIR" -type f -name '*.yml' -exec chmod 640 {} \;
find "$CONFIG_DIR" -type d -exec chmod 750 {} \;

# ---------------------------------------------------------------
# Crear servicio systemd
# ---------------------------------------------------------------
echo "Creando servicio systemd..."
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

# ---------------------------------------------------------------
# Habilitar e iniciar servicio
# ---------------------------------------------------------------
echo "Habilitando e iniciando Prometheus..."
systemctl daemon-reload >/dev/null 2>&1
systemctl enable --now prometheus >/dev/null 2>&1

sleep 3

# ---------------------------------------------------------------
# Validación
# ---------------------------------------------------------------
if systemctl is-active --quiet prometheus; then
  STATUS="instalado"
  echo "Prometheus iniciado correctamente."
else
  STATUS="error"
  echo "Error: El servicio prometheus no se inició correctamente."
  echo "Revisa los logs con: journalctl -u prometheus -n 30 -xe"
fi

# ---------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------
SERVERKIT_SUMMARY+="-------------------------------------------\n"
SERVERKIT_SUMMARY+="[Prometheus]\n"
SERVERKIT_SUMMARY+="Estado: ${STATUS}\n"
SERVERKIT_SUMMARY+="Versión: ${VERSION}\n"
SERVERKIT_SUMMARY+="Configuración: ${CONFIG_DIR}/prometheus.yml\n"
SERVERKIT_SUMMARY+="Datos: ${DATA_DIR}\n"
SERVERKIT_SUMMARY+="Binarios: ${BIN_PATH}, ${BIN_TOOL}\n"
SERVERKIT_SUMMARY+="Servicio: ${SERVICE}\n"
SERVERKIT_SUMMARY+="Endpoint: http://$(hostname -I | awk '{print $1}'):9090\n"
SERVERKIT_SUMMARY+="-------------------------------------------\n"

# ---------------------------------------------------------------
# Mostrar resumen si se ejecuta directamente
# ---------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo
  echo "==========================================="
  echo "Prometheus instalado correctamente."
  echo "==========================================="
  echo -e "$SERVERKIT_SUMMARY"
  echo
fi