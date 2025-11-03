#!/usr/bin/env bash
set -euo pipefail

# ===============================================
# bootstrap.sh — Inicialización principal de ServerKit
# ===============================================
# Ejecutar una sola vez tras instalar Ubuntu.
# Configura el entorno base del servidor, instala
# dependencias, crea el usuario administrativo,
# endurece SSH y prepara mecanismos de seguridad.
# ===============================================

# --- Carga entorno base ---
source /opt/serverkit/common/loader.sh

# --- Carga módulos principales ---
source /opt/serverkit/scripts/system/system_update.sh
source /opt/serverkit/scripts/system/user-setup.sh
source /opt/serverkit/scripts/system/ssh-hardening.sh
source /opt/serverkit/scripts/system/swap-setup.sh
source /opt/serverkit/scripts/system/timezone-setup.sh
source /opt/serverkit/scripts/logrotate/logrotate-setup.sh
source /opt/serverkit/scripts/fail2ban/fail2ban-setup.sh
source /opt/serverkit/scripts/cleaner-setup.sh

main() {
  log_start

  # --- Verificación de aprovisionamiento previo ---
  if [[ -f /opt/serverkit/.provisioned ]]; then
    log_warn "El sistema ya fue aprovisionado anteriormente."
    log_warn "Si desea repetir el proceso, elimine /opt/serverkit/.provisioned y vuelva a ejecutar este script."
    return 0
  fi

  log_info "Iniciando proceso de aprovisionamiento base de ServerKit..."
  echo "-------------------------------------------"

  # --- Ejecución de módulos principales ---
  system_update
  user_setup
  ssh_hardening
  swap_setup
  timezone_setup
  logrotate_setup
  fail2ban_setup

  # --- Configuración del limpiador automático ---
  cleaner_setup

  # --- Marcador de instalación ---
  touch /opt/serverkit/.provisioned

  # --- Información final ---
  local ip_address
  ip_address=$(curl -s ifconfig.me || echo "desconocida")

  echo
  echo "==========================================="
  echo "Servidor aprovisionado correctamente."
  echo "Hostname: $(hostname)"
  echo "Dirección IP pública: ${ip_address}"
  echo "Usuario administrativo: serverkit"
  echo "Contraseña temporal: ${RAW_PASSWORD:-'N/A'}"
  echo "-------------------------------------------"
  echo "Si existen acciones diferidas, se aplicarán al iniciar la próxima sesión root."
  echo
  echo "Para limpiar del historial los datos sensibles, ejecuta (una sola línea):"
  echo "  history -c && history -w && rm -f ~/.bash_history"
  echo "==========================================="

  log_end
}

main "$@"