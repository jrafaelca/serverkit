#!/usr/bin/env bash
set -euo pipefail

# ===============================================
# bootstrap.sh — Inicialización del servidor
# ===============================================
# Este script prepara una instancia Ubuntu 22.04/24.04
# con configuración base para producción segura.
# ===============================================

# Configura el entorno no interactivo para evitar prompts de APT
export DEBIAN_FRONTEND=noninteractive
LOG_FILE="/var/log/provision.log"

# --- Inicia logging ---
# Registra el inicio del aprovisionamiento en un archivo de log
echo "=== Provisioning started at $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "🧩 Iniciando proceso de aprovisionamiento..."
echo "📅 Fecha: $(date)"

# ===============================================
# Validaciones iniciales
# ===============================================

# --- Verifica permisos ---
# Comprueba que el script se esté ejecutando como root
if [[ $EUID -ne 0 ]]; then
  echo "❌ Este script debe ejecutarse como root (usa sudo)."
  exit 1
fi

# --- Evita ejecuciones repetidas ---
# Verifica si el servidor ya fue aprovisionado previamente
if [[ -f /root/.serverkit-provisioned ]]; then
  echo "⚠️ Este servidor ya fue aprovisionado anteriormente."
  echo "   Si necesitas volver a ejecutarlo, elimina /root/.serverkit-provisioned."
  exit 0
fi

# --- Comprueba distribución ---
# Verifica que el sistema operativo sea Ubuntu y esté en las versiones soportadas
if [[ ! -f /etc/os-release ]]; then
  echo "❌ No se puede determinar el sistema operativo (falta /etc/os-release)."
  exit 1
fi

source /etc/os-release
SUPPORTED_VERSIONS=("22.04" "24.04")

if [[ "$NAME" != "Ubuntu" ]]; then
  echo "Solo se admite Ubuntu (detectado: $NAME)."
  exit 1
fi

if [[ ! " ${SUPPORTED_VERSIONS[*]} " =~ ${VERSION_ID} ]]; then
  echo "❌ Ubuntu ${VERSION_ID} no soportado. Solo se admite ${SUPPORTED_VERSIONS[*]}."
  exit 1
fi

echo "✅ Sistema compatible detectado: $PRETTY_NAME"

# ===============================================
# Actualización del sistema
# ===============================================

# Actualiza los paquetes del sistema y los actualiza a la última versión
apt-get update -y
apt-get upgrade -y

# --- Paquetes esenciales ---
# Instala herramientas y utilidades necesarias para el servidor
apt-get install -yq \
  build-essential \
  cron \
  curl \
  fail2ban \
  git \
  jq \
  make \
  ncdu \
  net-tools \
  pkg-config \
  rsyslog \
  sendmail \
  unzip \
  uuid-runtime \
  whois \
  zip \
  zsh

# ===============================================
# Configuración SSH y usuario principal
# ===============================================

# --- Asegura la existencia del directorio SSH de root ---
# Crea el directorio .ssh para root si no existe y configura permisos seguros
if [ ! -d /root/.ssh ]; then
  mkdir -p /root/.ssh
  touch /root/.ssh/authorized_keys
fi

chown -R root:root /root/.ssh
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys
touch /root/.hushlogin

# --- Crea usuario administrativo ---
# Crea un nuevo usuario administrativo llamado 'serverkit'
useradd serverkit
mkdir -p /home/serverkit/.ssh /home/serverkit/.serverkit
adduser serverkit sudo

# --- Configura shell y entorno ---
# Configura el entorno del usuario 'serverkit' y copia configuraciones básicas
chsh -s /bin/bash serverkit
cp /root/.profile /home/serverkit/.profile
cp /root/.bashrc /home/serverkit/.bashrc
chown -R serverkit:serverkit /home/serverkit
chmod -R 755 /home/serverkit
touch /home/serverkit/.hushlogin

# --- Copia claves SSH desde root ---
# Copia las claves SSH de root al usuario 'serverkit'
cp -a /root/.ssh /home/serverkit/
chown -R serverkit:serverkit /home/serverkit/.ssh

# ===============================================
# Endurecimiento SSH
# ===============================================

# Configura el servicio SSH para deshabilitar contraseñas y permitir solo autenticación por clave pública
mkdir -p /etc/ssh/sshd_config.d
cat << EOF > /etc/ssh/sshd_config.d/49-serverkit.conf
# Configuración administrada por ServerKit
PasswordAuthentication no
PermitRootLogin prohibit-password
PubkeyAuthentication yes
EOF

# Genera claves de host SSH y reinicia el servicio SSH
ssh-keygen -A
systemctl restart ssh
systemctl enable ssh.service

# ===============================================
# Swap y rendimiento
# ===============================================

# --- Crea archivo swap de 1 GB si no existe ---
# Configura un archivo de swap para mejorar el rendimiento si no está configurado
if [ ! -f /swapfile ]; then
  fallocate -l 1G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo "/swapfile none swap sw 0 0" >> /etc/fstab
  echo "vm.swappiness=30" >> /etc/sysctl.conf
  echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
else
  echo "Swap existente, se omite creación."
fi

# ===============================================
# Zona horaria
# ===============================================

# Configura la zona horaria del servidor a UTC
if command -v timedatectl >/dev/null 2>&1; then
  timedatectl set-timezone UTC
else
  ln -sf /usr/share/zoneinfo/UTC /etc/localtime
  echo "UTC" > /etc/timezone
fi

# ===============================================
# Limpieza automática
# ===============================================

# --- Script de limpieza (archivos >30 días) ---
# Crea un script para limpiar archivos antiguos en directorios específicos
cat > /root/serverkit-cleanup.sh << 'EOF'
#!/usr/bin/env bash
UID_MIN=$(awk '/^UID_MIN/ {print $2}' /etc/login.defs)
UID_MAX=$(awk '/^UID_MAX/ {print $2}' /etc/login.defs)
HOME_DIRECTORIES=$(getent passwd | awk -F: -v min=$UID_MIN -v max=$UID_MAX '{if ($3>=min && $3<=max) print $6}')
for DIRECTORY in $HOME_DIRECTORIES; do
  TARGET="$DIRECTORY/.serverkit"
  [ -d "$TARGET" ] || continue
  echo "Cleaning $TARGET..."
  find "$TARGET" -type f -mtime +30 -print0 | xargs -r0 rm --
done
EOF
chmod +x /root/serverkit-cleanup.sh

# --- Cronjob diario de limpieza ---
# Configura un cronjob para ejecutar el script de limpieza diariamente
echo "" >> /etc/crontab
echo "# Serverkit Provisioning Cleanup" >> /etc/crontab
echo "0 0 * * * root bash /root/serverkit-cleanup.sh 2>&1" >> /etc/crontab

# ===============================================
# Hostname, Git y claves
# ===============================================

# Configura un hostname aleatorio para el servidor
HOSTNAME="serverkit-$(openssl rand -hex 3)"
echo "$HOSTNAME" > /etc/hostname
sed -i "s/127\.0\.0\.1.*localhost/127.0.0.1\t$HOSTNAME.localdomain $HOSTNAME localhost/" /etc/hosts
hostnamectl set-hostname "$HOSTNAME"

# Genera una contraseña aleatoria para el usuario 'serverkit'
RAW_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-16)
ENCRYPTED_PASSWORD=$(mkpasswd -m sha-512 "$RAW_PASSWORD")
usermod --password "$ENCRYPTED_PASSWORD" serverkit

# Genera claves SSH para el usuario 'serverkit'
ssh-keygen -f /home/serverkit/.ssh/id_rsa -t ed25519 -N ''
chown -R serverkit:serverkit /home/serverkit/.ssh
chmod 700 /home/serverkit/.ssh/id_rsa

# Agrega hosts de confianza para Git
{
  ssh-keyscan -H github.com
  ssh-keyscan -H bitbucket.org
  ssh-keyscan -H gitlab.com
} >> /home/serverkit/.ssh/known_hosts
chown serverkit:serverkit /home/serverkit/.ssh/known_hosts

# Configura Git para el usuario 'serverkit'
git config --global user.name "Serverkit"
git config --global user.email "serverkit@localhost"

# ===============================================
# Firewall y actualizaciones automáticas
# ===============================================

# Configura el firewall UFW si no está en un entorno AWS
if [ -z "${AWS_EXECUTION_ENV:-}" ]; then
  echo "Configurando firewall UFW local..."
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow 22
  ufw --force enable
else
  echo "Entorno Amazon EC2 detectado, omitiendo UFW."
fi

# Configura actualizaciones automáticas
apt-get update -o Acquire::AllowReleaseInfoChange=true
cat > /etc/apt/apt.conf.d/10periodic << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

# ===============================================
# Kernel y rotación de logs
# ===============================================

# Aplica parámetros del kernel
sysctl --system

# Configura la rotación de logs para limitar el tamaño máximo
for file in fail2ban rsyslog ufw; do
  conf="/etc/logrotate.d/$file"
  if [[ $(grep --count "maxsize" "$conf") == 0 ]]; then
    sed -i -r "s/^(\s*)(daily|weekly|monthly|yearly)$/\1\2\n\1maxsize 100M/" "$conf"
  else
    sed -i -r "s/^(\s*)maxsize.*$/\1maxsize 100M/" "$conf"
  fi
done

# Configura logrotate para ejecutarse cada hora
cat > /etc/systemd/system/timers.target.wants/logrotate.timer << EOF
[Unit]
Description=Rotation of log files
Documentation=man:logrotate(8) man:logrotate.conf(5)
[Timer]
OnCalendar=*:0/1
[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl restart logrotate.timer

# Limpia paquetes innecesarios
apt-get autoremove -y
apt-get clean

# ===============================================
# Finalización
# ===============================================

# Marca el servidor como aprovisionado
touch /root/.serverkit-provisioned

# Muestra información final del servidor
IP=$(curl -s ifconfig.me || echo "desconocida")
echo
echo "==========================================="
echo "✅ Servidor aprovisionado correctamente."
echo "Hostname: $HOSTNAME"
echo "Dirección IP pública: $IP"
echo "⚠️  IMPORTANTE: La contraseña se muestra solo UNA VEZ."
echo "Usuario: serverkit"
echo "Contraseña: $RAW_PASSWORD"
echo
echo "Copia y guarda esta contraseña ahora."
echo "==========================================="
echo "=== Provisioning completed at $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG_FILE"
