#!/usr/bin/env bash

# ===============================================
# Instalación de PgBouncer Exporter
# ===============================================
# Crea usuario "exporter" en PgBouncer y configura
# el servicio Prometheus pgbouncer_exporter.
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Iniciando instalación de PgBouncer Exporter..."

USERLIST="/etc/pgbouncer/userlist.txt"
SERVICE="/etc/systemd/system/pgbouncer-exporter.service"
BIN_PATH="/usr/local/bin/pgbouncer_exporter"

# ---------------------------------------------------------------
# Validar instalación de PgBouncer
# ---------------------------------------------------------------
if ! command -v pgbouncer >/dev/null 2>&1; then
  echo "Error: PgBouncer no está instalado. Instálalo antes de continuar."
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[PgBouncer Exporter]\n"
  SERVERKIT_SUMMARY+="Error: PgBouncer no encontrado. Instalación abortada.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  exit 1
fi

# ---------------------------------------------------------------
# Crear usuario "exporter"
# ---------------------------------------------------------------
EXPORTER_USER="exporter"
EXPORTER_PASS="$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-18)"
EXPORTER_MD5_HASH="md5$(printf '%s' "${EXPORTER_PASS}${EXPORTER_USER}" | md5sum | awk '{print $1}')"

if ! grep -q "\"${EXPORTER_USER}\"" "$USERLIST" 2>/dev/null; then
  echo "\"${EXPORTER_USER}\" \"${EXPORTER_MD5_HASH}\"" >> "$USERLIST"
  chown pgbouncer:pgbouncer "$USERLIST"
  chmod 600 "$USERLIST"
  echo "Usuario 'exporter' agregado al userlist de PgBouncer."
else
  echo "El usuario 'exporter' ya existe en PgBouncer. Omitiendo creación."
fi

# ---------------------------------------------------------------
# Descargar la última versión estable de pgbouncer_exporter
# ---------------------------------------------------------------
echo "Descargando la última versión de pgbouncer_exporter..."
LATEST_URL=$(curl -s https://api.github.com/repos/prometheus-community/pgbouncer_exporter/releases/latest \
  | grep browser_download_url \
  | grep linux-amd64 \
  | cut -d '"' -f 4)

cd /usr/local/bin
wget -q "$LATEST_URL" -O pgbouncer_exporter.tar.gz
tar -xzf pgbouncer_exporter.tar.gz >/dev/null 2>&1
mv pgbouncer_exporter-*/pgbouncer_exporter "$BIN_PATH" 2>/dev/null || true
chmod +x "$BIN_PATH"
rm -rf pgbouncer_exporter-* pgbouncer_exporter.tar.gz

# ---------------------------------------------------------------
# Crear servicio systemd
# ---------------------------------------------------------------
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

systemctl daemon-reload >/dev/null 2>&1
systemctl enable --now pgbouncer-exporter >/dev/null 2>&1
sleep 3

# ---------------------------------------------------------------
# Validación
# ---------------------------------------------------------------
if systemctl is-active --quiet pgbouncer-exporter; then
  echo "PgBouncer Exporter instalado y en ejecución."
  STATUS="instalado"
else
  echo "Error: el servicio pgbouncer-exporter no se inició correctamente."
  STATUS="error"
fi

# ---------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------
SERVERKIT_SUMMARY+="-------------------------------------------\n"
SERVERKIT_SUMMARY+="[PgBouncer Exporter]\n"
SERVERKIT_SUMMARY+="Estado: ${STATUS}\n"
SERVERKIT_SUMMARY+="Usuario: ${EXPORTER_USER}\n"
SERVERKIT_SUMMARY+="Contraseña: ${EXPORTER_PASS}\n"
SERVERKIT_SUMMARY+="Endpoint métricas: http://localhost:9187/metrics\n"
SERVERKIT_SUMMARY+="Archivo de servicio: ${SERVICE}\n"
SERVERKIT_SUMMARY+="-------------------------------------------\n"

# ---------------------------------------------------------------
# Mostrar resumen si se ejecuta directamente
# ---------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo
  echo "==========================================="
  echo "PgBouncer Exporter instalado correctamente."
  echo "==========================================="
  echo -e "$SERVERKIT_SUMMARY"
  echo
fi