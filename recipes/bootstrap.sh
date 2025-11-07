#!/usr/bin/env bash
set -e

# ===============================================
# bootstrap.sh — Inicialización principal de ServerKit
# ===============================================
# Ejecutar una sola vez tras instalar Ubuntu.
# Configura el entorno base del servidor, instala
# dependencias, crea el usuario administrativo,
# endurece SSH y prepara mecanismos de seguridad.
# ===============================================

# --- Carga entorno base ---
source /opt/serverkit/scripts/common/loader.sh

# --- Carga módulos ---
source /opt/serverkit/scripts/serverkit/setup-user.sh
source /opt/serverkit/scripts/serverkit/setup-cleaner.sh

source /opt/serverkit/scripts/system/setup-system.sh
source /opt/serverkit/scripts/system/setup-ssh.sh
source /opt/serverkit/scripts/system/setup-swap.sh
source /opt/serverkit/scripts/system/setup-timezone.sh

source /opt/serverkit/scripts/logrotate/install.sh
source /opt/serverkit/scripts/fail2ban/install.sh

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

  # --- Ejecución de módulos ---
  setup_serverkit_user
  setup_serverkit_cleaner

  setup_system
  setup_system_ssh
  setup_system_swap
  setup_system_timezone
  
  install_logrotate
  install_fail2ban

  # --- Marcador de instalación ---
  touch /opt/serverkit/.provisioned

  # --- Información final ---
  echo
  echo "==========================================="
  echo "Servidor aprovisionado correctamente."
  echo "Hostname: $(hostname)"
  echo "Usuario administrativo: serverkit"
  echo "Contraseña temporal: ${RAW_PASSWORD:-'N/A'}"
  echo "-------------------------------------------"
  echo
  echo "Para limpiar del historial los datos sensibles, ejecuta (una sola línea):"
  echo "  history -c && history -w && rm -f ~/.bash_history"
  echo "==========================================="

  log_end
}

main "$@"