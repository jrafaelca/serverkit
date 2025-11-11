#!/usr/bin/env bash

# ===============================================
# Configuración segura de SSH
# ===============================================
# Aplica políticas seguras de acceso remoto y crea
# una regla de logrotate para /var/log/auth.log.
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Endureciendo configuración SSH..."

CONF_FILE="/etc/ssh/sshd_config.d/89-serverkit.conf"
LOGROTATE_FILE="/etc/logrotate.d/sshd"
RUNTIME_DIR="/run/sshd"

# ---------------------------------------------------------------
# Crear directorio de configuración si no existe
# ---------------------------------------------------------------
[[ -d /etc/ssh/sshd_config.d ]] || mkdir -p /etc/ssh/sshd_config.d

# ---------------------------------------------------------------
# Crear archivo de configuración segura (idempotente)
# ---------------------------------------------------------------
cat > "$CONF_FILE" <<'EOF'
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

chmod 600 "$CONF_FILE"
echo "Archivo de configuración SSH creado: ${CONF_FILE}"

# ---------------------------------------------------------------
# Verificar o generar claves host SSH
# ---------------------------------------------------------------
ssh-keygen -A >/dev/null 2>&1
echo "Claves host SSH verificadas."

# ---------------------------------------------------------------
# Crear regla de logrotate (si no existe)
# ---------------------------------------------------------------
if [[ ! -f "$LOGROTATE_FILE" ]]; then
  cat > "$LOGROTATE_FILE" <<'EOF'
/var/log/auth.log {
    missingok
    notifempty
    size 100M
    rotate 5
    compress
    delaycompress
    postrotate
        systemctl reload ssh.service > /dev/null 2>&1 || true
    endscript
}
EOF
  echo "Regla de logrotate creada: ${LOGROTATE_FILE}"
else
  echo "Regla de logrotate existente. No se realizaron cambios."
fi

# ---------------------------------------------------------------
# Asegurar directorio de runtime de SSH
# ---------------------------------------------------------------
if [[ ! -d "$RUNTIME_DIR" ]]; then
  mkdir -p "$RUNTIME_DIR"
  chmod 755 "$RUNTIME_DIR"
  echo "Directorio ${RUNTIME_DIR} creado."
fi

# ---------------------------------------------------------------
# Validación de configuración SSH
# ---------------------------------------------------------------
if sshd -t >/dev/null 2>&1; then
  systemctl reload ssh >/dev/null 2>&1 || true
  echo "✅ Validación de configuración SSH exitosa. Servicio recargado."

  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[SSH seguro]\n"
  SERVERKIT_SUMMARY+="Archivo de configuración: ${CONF_FILE}\n"
  SERVERKIT_SUMMARY+="Directorio runtime: ${RUNTIME_DIR}\n"
  SERVERKIT_SUMMARY+="Regla logrotate: ${LOGROTATE_FILE}\n"
  SERVERKIT_SUMMARY+="Estado: configuración validada y servicio recargado.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
else
  echo "❌ Error en configuración SSH. Revisa ${CONF_FILE}"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[SSH seguro]\n"
  SERVERKIT_SUMMARY+="Error: configuración inválida. Verifique el archivo generado.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  exit 1
fi

# ---------------------------------------------------------------
# Mostrar resumen si se ejecuta directamente
# ---------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo
  echo "==========================================="
  echo "Configuración segura de SSH"
  echo "==========================================="
  echo -e "$SERVERKIT_SUMMARY"
  echo
fi