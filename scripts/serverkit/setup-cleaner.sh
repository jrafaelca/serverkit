#!/usr/bin/env bash
set -e

# ===============================================
# Configuración de limpieza automática
# ===============================================
# Crea un script que limpia archivos viejos en ~/.serverkit
# para todos los usuarios del sistema y programa su ejecución
# diaria mediante cron.
# ===============================================

[[ -z "${SERVERKIT_ENV_INITIALIZED:-}" ]] && source /opt/serverkit/scripts/common/loader.sh

setup_serverkit_cleaner() {
  log_info "Iniciando configuración de limpieza automática..."

  # --- Crea directorio si no existe ---
  [[ -d /opt/serverkit ]] || mkdir -p /opt/serverkit

  # --- Script de limpieza ---
  cat > /opt/serverkit/cleanup.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

UID_MIN=$(awk '/^UID_MIN/ {print $2}' /etc/login.defs)
UID_MAX=$(awk '/^UID_MAX/ {print $2}' /etc/login.defs)

getent passwd | awk -F: -v min=$UID_MIN -v max=$UID_MAX '{if ($3>=min && $3<=max) print $6}' | while read -r HOME_DIR; do
  TARGET="$HOME_DIR/.serverkit"
  if [[ -d "$TARGET" ]]; then
    find "$TARGET" -type f -mtime +30 -delete
  fi
done
EOF

  chmod +x /opt/serverkit/cleanup.sh
  log_info "Script de limpieza creado: /opt/serverkit/cleanup.sh"

  # --- Configura tarea diaria ---
  if ! grep -q "/opt/serverkit/cleanup.sh" /etc/crontab; then
    echo "0 0 * * * root bash /opt/serverkit/cleanup.sh >/dev/null 2>&1" >> /etc/crontab
    log_info "Tarea cron diaria añadida a /etc/crontab"
  fi

  # --- Validación ---
  if [[ -x /opt/serverkit/cleanup.sh ]]; then
    log_info "✅ Limpieza automática configurada correctamente."
  else
    log_error "❌ No se pudo configurar la limpieza automática."
    return 1
  fi
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && setup_serverkit_cleaner "$@"