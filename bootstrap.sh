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
source /opt/serverkit/modules/update-system.sh
source /opt/serverkit/modules/setup-user.sh
source /opt/serverkit/modules/hardening-ssh.sh
source /opt/serverkit/modules/setup-swap.sh
source /opt/serverkit/modules/setup-timezone.sh
source /opt/serverkit/modules/setup-cleanup.sh
source /opt/serverkit/modules/setup-firewall.sh
source /opt/serverkit/modules/setup-logrotate.sh
source /opt/serverkit/modules/setup-fail2ban.sh
source /opt/serverkit/modules/setup-deferred-actions.sh

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
  update_system
  setup_user
  harden_ssh
  setup_swap
  setup_timezone
  setup_cleanup
  setup_firewall
  setup_logrotate
  setup_fail2ban

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