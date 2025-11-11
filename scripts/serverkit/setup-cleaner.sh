#!/usr/bin/env bash

# ===============================================
# Configuración de limpieza automática
# ===============================================
# Crea un script que elimina archivos antiguos en
# ~/.serverkit de todos los usuarios del sistema y
# programa su ejecución diaria mediante cron.
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Configurando tareas automáticas de limpieza..."

CLEANUP_SCRIPT="/opt/serverkit/cleanup.sh"
CRON_FILE="/etc/crontab"

# ---------------------------------------------------------------
# Crear directorio base si no existe
# ---------------------------------------------------------------
[[ -d /opt/serverkit ]] || mkdir -p /opt/serverkit

# ---------------------------------------------------------------
# Crear script de limpieza
# ---------------------------------------------------------------
cat > "$CLEANUP_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

UID_MIN=$(awk '/^UID_MIN/ {print $2}' /etc/login.defs)
UID_MAX=$(awk '/^UID_MAX/ {print $2}' /etc/login.defs)

getent passwd | awk -F: -v min=$UID_MIN -v max=$UID_MAX '{if ($3>=min && $3<=max) print $6}' | while read -r HOME_DIR; do
  TARGET="$HOME_DIR/.serverkit"
  if [[ -d "$TARGET" ]]; then
    find "$TARGET" -type f -mtime +30 -print -delete >/dev/null 2>&1 || true
  fi
done
EOF

chmod 750 "$CLEANUP_SCRIPT"
chown root:root "$CLEANUP_SCRIPT"
echo "Script de limpieza creado: ${CLEANUP_SCRIPT}"

# ---------------------------------------------------------------
# Configurar tarea diaria en cron (si no existe)
# ---------------------------------------------------------------
if ! grep -qF "$CLEANUP_SCRIPT" "$CRON_FILE"; then
  echo "0 0 * * * root bash ${CLEANUP_SCRIPT} >/dev/null 2>&1" >> "$CRON_FILE"
  echo "Tarea cron diaria añadida a ${CRON_FILE}"
else
  echo "Tarea cron existente. No se realizaron cambios."
fi

# ---------------------------------------------------------------
# Validación
# ---------------------------------------------------------------
if [[ -x "$CLEANUP_SCRIPT" ]]; then
  STATUS="configurada"
  echo "Limpieza automática configurada correctamente."
else
  STATUS="error"
  echo "Error: No se pudo configurar la limpieza automática."
fi

# ---------------------------------------------------------------
# Resumen ServerKit
# ---------------------------------------------------------------
SERVERKIT_SUMMARY+="-------------------------------------------\n"
SERVERKIT_SUMMARY+="[Limpieza automática]\n"
SERVERKIT_SUMMARY+="Script: ${CLEANUP_SCRIPT}\n"
SERVERKIT_SUMMARY+="Programación: diaria (00:00 vía cron)\n"
SERVERKIT_SUMMARY+="Acción: eliminar archivos >30 días en ~/.serverkit\n"
SERVERKIT_SUMMARY+="Estado: ${STATUS}\n"
SERVERKIT_SUMMARY+="-------------------------------------------\n"

# ---------------------------------------------------------------
# Mostrar resumen si se ejecuta directamente
# ---------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo
  echo "==========================================="
  echo "Configuración de limpieza automática"
  echo "==========================================="
  echo -e "$SERVERKIT_SUMMARY"
  echo
fi