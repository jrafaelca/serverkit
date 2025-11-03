#!/usr/bin/env bash
set -euo pipefail

# ===============================================
# update-system.sh — Actualización del sistema base
# ===============================================
# Actualiza los paquetes del sistema, instala las
# utilidades esenciales y limpia paquetes antiguos.
# ===============================================

[[ -z "${SERVERKIT_ENV_INITIALIZED:-}" ]] && source /opt/serverkit/common/loader.sh

update_system() {
  log_info "Iniciando actualización del sistema base..."

  # --- Ajuste de timeout para evitar conflictos con dpkg locks (apt concurrente) ---
  cat > /etc/apt/apt.conf.d/90lock-timeout <<'EOF'
DPkg::Lock::Timeout "300";
EOF
  log_info "Timeout de bloqueo de APT configurado en 300 segundos."

  # --- Actualización del sistema ---
  apt-get update -y >/dev/null 2>&1
  apt-get upgrade -y >/dev/null 2>&1
  log_info "Paquetes del sistema actualizados correctamente."

  # --- Instalación de utilidades esenciales ---
  log_info "Instalando paquetes esenciales..."

  ESSENTIALS=(
    build-essential
    cron
    curl
    git
    jq
    make
    ncdu
    net-tools
    pkg-config
    rsyslog
    sendmail
    unzip
    uuid-runtime
    whois
    zip
    zsh
  )
  apt-get install -yq "${ESSENTIALS[@]}" >/dev/null 2>&1

  log_info "Paquetes esenciales instalados correctamente."

  # --- Limpieza del sistema ---
  apt-get autoremove -y >/dev/null 2>&1
  apt-get clean >/dev/null 2>&1
  log_info "Limpieza del sistema completada."

  # --- Configuración de actualizaciones automáticas ---
  log_info "Configurando actualizaciones automáticas..."

  apt-get install -yq unattended-upgrades >/dev/null 2>&1

  cat <<EOF >/etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Allowed-Origins {
        "\${distro_id}:\${distro_codename}-security";
};
EOF

  cat <<EOF >/etc/apt/apt.conf.d/10periodic
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

  log_info "Actualizaciones automáticas configuradas correctamente."

  # --- Validación final ---
  if command -v git >/dev/null && command -v curl >/dev/null; then
    log_info "✅ Actualización del sistema completada correctamente."
  else
    log_warn "⚠️ Algunos paquetes esenciales podrían no haberse instalado correctamente."
  fi
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && update_system "$@"