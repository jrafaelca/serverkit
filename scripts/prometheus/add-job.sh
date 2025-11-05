#!/usr/bin/env bash

# ===============================================
# Agrega un nuevo job a Prometheus
# ===============================================
# Este script toma un archivo desde scripts/prometheus/jobs/
# y lo anexa a /etc/prometheus/prometheus.yml.
# Luego recarga el servicio de Prometheus.
#
# Ejemplo:
#   ./add-job.sh pgbouncer.yml
# ===============================================

[[ -z "${SERVERKIT_ENV_INITIALIZED:-}" ]] && source /opt/serverkit/scripts/common/loader.sh

add_job() {
  local JOB_NAME="${1:-}"
  local PROM_CONFIG="/etc/prometheus/prometheus.yml"
  local JOB_FILE="${BASE_DIR}/scripts/prometheus/jobs/${JOB_NAME}"

  if [[ -z "$JOB_NAME" ]]; then
    log_error "Debes indicar el nombre del job. Ejemplo:"
    echo "  $(basename "$0") pgbouncer.yml"
    exit 1
  fi

  if [[ ! -f "$JOB_FILE" ]]; then
    log_error "El archivo ${JOB_FILE} no existe."
    exit 1
  fi

  log_info "Agregando configuración desde ${JOB_FILE}..."

  # Crear respaldo de seguridad
  cp "$PROM_CONFIG" "${PROM_CONFIG}.bak_$(date +%Y%m%d%H%M%S)"

  # Validar formato YAML
  if ! grep -q "^scrape_configs:" "$PROM_CONFIG"; then
    log_error "El archivo de configuración no contiene 'scrape_configs:'. Verifica ${PROM_CONFIG}."
    exit 1
  fi

  # Insertar el nuevo job
  awk -v job_file="$JOB_FILE" '
    /^  - job_name:/ {last=NR}
    {lines[NR]=$0}
    END {
      for (i=1; i<=NR; i++) print lines[i]
      print ""
      system("sed \"s/^/  /\" " job_file)
      print ""
    }
  ' "$PROM_CONFIG" > "${PROM_CONFIG}.tmp" && mv "${PROM_CONFIG}.tmp" "$PROM_CONFIG"

  chown prometheus:prometheus "$PROM_CONFIG"
  chmod 640 "$PROM_CONFIG"

  # Recargar Prometheus
  log_info "Recargando Prometheus..."
  systemctl restart prometheus

  if systemctl is-active --quiet prometheus; then
    log_info "✅ Job '${JOB_NAME}' agregado correctamente y Prometheus recargado."
  else
    log_error "⚠️  Prometheus no está activo. Revisa los logs:"
    echo "   journalctl -u prometheus -n 20 -xe"
  fi
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && add_job "$@"