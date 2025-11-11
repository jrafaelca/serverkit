#!/usr/bin/env bash

# ===============================================
# Agrega un nuevo job a Prometheus (no interactivo)
# ===============================================
# Toma un archivo desde scripts/prometheus/jobs/
# y lo anexa a /etc/prometheus/prometheus.yml (o ruta especificada).
#
# Uso:
#   ./add-job.sh pgbouncer.yml [/etc/prometheus/prometheus.yml]
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

JOB_NAME="${1:-}"
PROM_CONFIG="${2:-/etc/prometheus/prometheus.yml}"
BASE_DIR="/opt/serverkit"
JOBS_DIR="${BASE_DIR}/scripts/prometheus/jobs"
JOB_FILE="${JOBS_DIR}/${JOB_NAME}"

echo
echo "Iniciando adición de job a Prometheus..."
echo "Archivo de configuración: ${PROM_CONFIG}"

# ---------------------------------------------------------------
# Validaciones
# ---------------------------------------------------------------
if [[ -z "$JOB_NAME" ]]; then
  echo "Error: Debes indicar el nombre del job (ej: pgbouncer.yml)."
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Prometheus Job]\n"
  SERVERKIT_SUMMARY+="Error: No se indicó el nombre del job.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  exit 1
fi

if [[ ! -f "$JOB_FILE" ]]; then
  echo "Error: No se encontró ${JOB_FILE}."
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Prometheus Job]\n"
  SERVERKIT_SUMMARY+="Error: No existe el archivo ${JOB_FILE}.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  exit 1
fi

if [[ ! -f "$PROM_CONFIG" ]]; then
  echo "Error: No se encontró el archivo ${PROM_CONFIG}."
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Prometheus Job]\n"
  SERVERKIT_SUMMARY+="Error: No se encontró ${PROM_CONFIG}.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  exit 1
fi

if ! grep -q "^scrape_configs:" "$PROM_CONFIG"; then
  echo "Error: ${PROM_CONFIG} no contiene 'scrape_configs:'."
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Prometheus Job]\n"
  SERVERKIT_SUMMARY+="Error: Falta la sección scrape_configs en ${PROM_CONFIG}.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  exit 1
fi

# ---------------------------------------------------------------
# Crear respaldo
# ---------------------------------------------------------------
BACKUP_FILE="${PROM_CONFIG}.bak_$(date +%Y%m%d%H%M%S)"
cp "$PROM_CONFIG" "$BACKUP_FILE" >/dev/null 2>&1
echo "Respaldo creado: ${BACKUP_FILE}"

# ---------------------------------------------------------------
# Verificar duplicado
# ---------------------------------------------------------------
JOB_ID=$(grep -oP "^  - job_name:\s*'\K[^']+" "$JOB_FILE" || grep -oP '^  - job_name:\s*"\K[^"]+' "$JOB_FILE")
if grep -q "job_name: ['\"]${JOB_ID}['\"]" "$PROM_CONFIG"; then
  echo "El job '${JOB_ID}' ya está presente en la configuración. Omitiendo inserción."
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Prometheus Job]\n"
  SERVERKIT_SUMMARY+="Job: ${JOB_ID}\n"
  SERVERKIT_SUMMARY+="Estado: ya existía, sin cambios.\n"
  SERVERKIT_SUMMARY+="Archivo: ${PROM_CONFIG}\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  exit 0
fi

# ---------------------------------------------------------------
# Insertar el nuevo bloque
# ---------------------------------------------------------------
awk -v job_file="$JOB_FILE" '
  { print $0 }
  END {
    print ""
    system("sed \"s/^/  /\" " job_file)
    print ""
  }
' "$PROM_CONFIG" > "${PROM_CONFIG}.tmp" && mv "${PROM_CONFIG}.tmp" "$PROM_CONFIG"

chown prometheus:prometheus "$PROM_CONFIG"
chmod 640 "$PROM_CONFIG"

# ---------------------------------------------------------------
# Recargar Prometheus
# ---------------------------------------------------------------
systemctl restart prometheus >/dev/null 2>&1
sleep 2

if systemctl is-active --quiet prometheus; then
  STATUS="agregado"
  echo "Job '${JOB_ID}' agregado y Prometheus recargado."
else
  STATUS="error"
  echo "Error: Prometheus no se inició correctamente."
  echo "Revisa con: journalctl -u prometheus -n 20 -xe"
fi

# ---------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------
SERVERKIT_SUMMARY+="-------------------------------------------\n"
SERVERKIT_SUMMARY+="[Prometheus Job]\n"
SERVERKIT_SUMMARY+="Job: ${JOB_ID}\n"
SERVERKIT_SUMMARY+="Archivo origen: ${JOB_FILE}\n"
SERVERKIT_SUMMARY+="Configuración: ${PROM_CONFIG}\n"
SERVERKIT_SUMMARY+="Estado: ${STATUS}\n"
SERVERKIT_SUMMARY+="-------------------------------------------\n"

# ---------------------------------------------------------------
# Mostrar resumen si se ejecuta directamente
# ---------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo
  echo "==========================================="
  echo "Job agregado a Prometheus (no interactivo)"
  echo "==========================================="
  echo -e "$SERVERKIT_SUMMARY"
  echo
fi