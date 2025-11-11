#!/usr/bin/env bash

# ===============================================
# Configuración del sistema base
# ===============================================
# Actualiza los paquetes del sistema, instala las
# utilidades esenciales y limpia paquetes antiguos.
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Configurando parámetros básicos del sistema..."

# ---------------------------------------------------------------
# Configurar timeout de bloqueo de APT
# ---------------------------------------------------------------
cat > /etc/apt/apt.conf.d/90lock-timeout <<'EOF'
DPkg::Lock::Timeout "300";
EOF
chmod 644 /etc/apt/apt.conf.d/90lock-timeout
echo "Timeout de bloqueo de APT configurado en 300 segundos."

# ---------------------------------------------------------------
# Actualización del sistema
# ---------------------------------------------------------------
echo "Actualizando paquetes del sistema..."
if apt-get update -y >/dev/null 2>&1 && apt-get upgrade -y >/dev/null 2>&1; then
  echo "Paquetes del sistema actualizados correctamente."
else
  echo "❌ Error durante la actualización de paquetes."
fi

# ---------------------------------------------------------------
# Instalación de utilidades esenciales
# ---------------------------------------------------------------
echo "Instalando paquetes esenciales..."
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

if apt-get install -yq "${ESSENTIALS[@]}" >/dev/null 2>&1; then
  echo "Paquetes esenciales instalados correctamente."
else
  echo "⚠️  Algunos paquetes esenciales podrían no haberse instalado correctamente."
fi

# ---------------------------------------------------------------
# Limpieza del sistema
# ---------------------------------------------------------------
apt-get autoremove -y >/dev/null 2>&1
apt-get clean -y >/dev/null 2>&1
echo "Limpieza del sistema completada."

# ---------------------------------------------------------------
# Configurar actualizaciones automáticas
# ---------------------------------------------------------------
echo "Configurando actualizaciones automáticas..."
if apt-get install -yq unattended-upgrades >/dev/null 2>&1; then
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

  chmod 644 /etc/apt/apt.conf.d/50unattended-upgrades /etc/apt/apt.conf.d/10periodic
  echo "Actualizaciones automáticas configuradas correctamente."
else
  echo "❌ No se pudo instalar 'unattended-upgrades'."
fi

# ---------------------------------------------------------------
# Validación y resumen
# ---------------------------------------------------------------
if command -v git >/dev/null && command -v curl >/dev/null; then
  echo "✅ Actualización del sistema completada correctamente."

  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Sistema base]\n"
  SERVERKIT_SUMMARY+="Estado: Actualización e instalación completadas correctamente.\n"
  SERVERKIT_SUMMARY+="Timeout APT: 300 segundos.\n"
  SERVERKIT_SUMMARY+="Paquetes esenciales instalados: ${#ESSENTIALS[@]}\n"
  SERVERKIT_SUMMARY+="Actualizaciones automáticas: habilitadas.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
else
  echo "⚠️  Algunos paquetes esenciales podrían no haberse instalado correctamente."

  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Sistema base]\n"
  SERVERKIT_SUMMARY+="Estado: Completado con advertencias. Verifique instalación de paquetes.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
fi

# ---------------------------------------------------------------
# Mostrar resumen si se ejecuta directamente
# ---------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo
  echo "==========================================="
  echo "Configuración del sistema base"
  echo "==========================================="
  echo -e "$SERVERKIT_SUMMARY"
  echo
fi