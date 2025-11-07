#!/usr/bin/env bash
set -e

# ===============================================
# Configuración segura de SSH
# ===============================================
# Aplica políticas seguras de acceso remoto y crea
# una regla de logrotate para /var/log/auth.log.
# ===============================================

# Carga entorno si no está inicializado
[[ -z "${SERVERKIT_ENV_INITIALIZED:-}" ]] && source /opt/serverkit/scripts/common/loader.sh

setup_system_ssh() {
  log_info "Iniciando endurecimiento de SSH..."

  # --- Configuración segura ---
  [[ -d /etc/ssh/sshd_config.d ]] || mkdir /etc/ssh/sshd_config.d

  cat > /etc/ssh/sshd_config.d/89-serverkit.conf <<'EOF'
# Configuración gestionada por ServerKit
PasswordAuthentication no
PermitRootLogin prohibit-password
PubkeyAuthentication yes
ChallengeResponseAuthentication no
X11Forwarding no
UseDNS no
PermitEmptyPasswords no
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 30
MaxAuthTries 3
AllowTcpForwarding no
EOF
  log_info "Archivo de configuración SSH creado: /etc/ssh/sshd_config.d/89-serverkit.conf"

  # --- Claves host SSH ---
  ssh-keygen -A
  log_info "Claves host SSH verificadas."

  # --- Regla de logrotate ---
  TARGET_FILE="/etc/logrotate.d/sshd"
  if [[ ! -f "$TARGET_FILE" ]]; then
    cat > "$TARGET_FILE" <<'EOF'
/var/log/auth.log {
    missingok
    notifempty
    size 100M
    rotate 5
    compress
    delaycompress
    postrotate
        systemctl restart ssh.service > /dev/null 2>&1 || true
    endscript
}
EOF
    log_info "Regla de logrotate creada: $TARGET_FILE"
  fi

  # --- Asegura el directorio de runtime ---
  if [[ ! -d /run/sshd ]]; then
    mkdir -p /run/sshd
    chmod 755 /run/sshd
    log_info "Directorio /run/sshd creado para privilegios de SSH."
  fi

  # --- Validación ---
  if sshd -t >/dev/null 2>&1; then
    log_info "✅ Validación de configuración SSH exitosa."
    log_info "✅ Endurecimiento SSH completado correctamente."
  else
    log_error "❌ Error en configuración SSH. Revisa /etc/ssh/sshd_config.d/89-serverkit.conf"
    return 1
  fi
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && setup_system_ssh "$@"