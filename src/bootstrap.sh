#!/usr/bin/env bash
set -euo pipefail

# ===============================================
# 🚀 provision.sh — Inicialización del servidor
# ===============================================
# Este script prepara una instancia Ubuntu 22.04/24.04
# con configuración base para producción segura.
# ===============================================

# --- Modo no interactivo para evitar prompts de APT ---
export DEBIAN_FRONTEND=noninteractive
LOG_FILE="/var/log/provision.log"

# --- Inicia logging ---
echo "=== Provisioning started at $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "🧩 Iniciando proceso de aprovisionamiento..."
echo "📅 Fecha: $(date)"

# ===============================================
# Validaciones iniciales
# ===============================================

# --- Verifica permisos ---
if [[ $EUID -ne 0 ]]; then
  echo "❌ Este script debe ejecutarse como root (usa sudo)."
  exit 1
fi

# --- Evita ejecuciones repetidas ---
if [[ -f /root/.serverkit-provisioned ]]; then
  echo "⚠️ Este servidor ya fue aprovisionado anteriormente."
  echo "   Si necesitas volver a ejecutarlo, elimina /root/.serverkit-provisioned."
  exit 0
fi

# --- Comprueba distribución ---
if [[ ! -f /etc/os-release ]]; then
  echo "❌ No se puede determinar el sistema operativo (falta /etc/os-release)."
  exit 1
fi

source /etc/os-release
SUPPORTED_VERSIONS=("22.04" "24.04")

if [[ "$NAME" != "Ubuntu" || ! " ${SUPPORTED_VERSIONS[@]} " =~ " ${VERSION_ID} " ]]; then
  echo "❌ Ubuntu ${VERSION_ID} no soportado. Solo se admite ${SUPPORTED_VERSIONS[*]}."
  exit 1
fi

echo "✅ Sistema compatible detectado: $PRETTY_NAME"

# ===============================================
# Actualización del sistema
# ===============================================

apt-get update -y
apt-get upgrade -y

# --- Instala utilidades esenciales ---
apt-get install -yq \
  build-essential \             # herramientas gcc/g++/make
  cron \                        # tareas programadas
  curl \                        # descargas HTTP
  fail2ban \                    # protección de SSH
  git \                         # control de versiones
  jq \                          # manipulación JSON
  make \                        # utilidad de build
  ncdu \                        # uso de disco
  net-tools \                   # ifconfig, netstat
  pkg-config \                  # compilación
  rsyslog \                     # logging del sistema
  sendmail \                    # correo básico
  unzip \                       # descompresión ZIP
  uuid-runtime \                # generación UUID
  whois \                       # consultas WHOIS + util mkpasswd
  zip \                         # compresión ZIP
  zsh                           # shell opcional

# ===============================================
# Configuración SSH y usuario principal
# ===============================================

# --- Asegura la existencia del directorio SSH de root ---
if [ ! -d /root/.ssh ]; then
  mkdir -p /root/.ssh
  touch /root/.ssh/authorized_keys
fi

chown -R root:root /root/.ssh
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys
touch /root/.hushlogin  # silencia mensajes de login

# --- Crea el usuario administrativo 'serverkit' ---
useradd serverkit
mkdir -p /home/serverkit/.ssh /home/serverkit/.serverkit
adduser serverkit sudo

# --- Configura shell y entorno ---
chsh -s /bin/bash serverkit
cp /root/.profile /home/serverkit/.profile
cp /root/.bashrc /home/serverkit/.bashrc
chown -R serverkit:serverkit /home/serverkit
chmod -R 755 /home/serverkit
touch /home/serverkit/.hushlogin

# --- Copia claves SSH desde root ---
cp -a /root/.ssh /home/serverkit/
chown -R serverkit:serverkit /home/serverkit/.ssh

# --- Elimina el usuario predeterminado 'ubuntu' (por motivos de seguridad) ---
if id ubuntu &>/dev/null; then
  echo "⚠️  Eliminando usuario 'ubuntu' (sudo sin contraseña detectado)..."

  # Finaliza procesos activos (sin error si no hay)
  pkill -u ubuntu 2>/dev/null || true

  # Elimina permisos sudo heredados
  rm -f /etc/sudoers.d/90-cloud-init-users

  # Elimina el usuario y su directorio home
  deluser --remove-home ubuntu 2>/dev/null || rm -rf /home/ubuntu

  echo "✅ Usuario 'ubuntu' eliminado correctamente."
fi

# --- Endurece configuración SSH ---
mkdir -p /etc/ssh/sshd_config.d
cat << EOF > /etc/ssh/sshd_config.d/49-serverkit.conf
# Configuración administrada por ServerKit
PasswordAuthentication no
PermitRootLogin prohibit-password
PubkeyAuthentication yes
EOF

# --- Genera claves host y activa SSH ---
ssh-keygen -A
service ssh restart
systemctl enable ssh.service

# ===============================================
# Swap y rendimiento
# ===============================================

# --- Crea archivo swap de 1 GB si no existe ---
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
# Configuración regional y zona horaria
# ===============================================

if command -v timedatectl >/dev/null 2>&1; then
  timedatectl set-timezone UTC
else
  ln -sf /usr/share/zoneinfo/UTC /etc/localtime
  echo "UTC" > /etc/timezone
fi

# ===============================================
# Limpieza automática (archivos antiguos)
# ===============================================

# --- Script de limpieza (archivos >30 días) ---
cat > /root/serverkit-cleanup.sh << 'EOF'
#!/usr/bin/env bash
UID_MIN=$(awk '/^UID_MIN/ {print $2}' /etc/login.defs)
UID_MAX=$(awk '/^UID_MAX/ {print $2}' /etc/login.defs)
HOME_DIRECTORIES=$(eval getent passwd {0,{${UID_MIN}..${UID_MAX}}} | cut -d: -f6)
for DIRECTORY in $HOME_DIRECTORIES; do
  TARGET="$DIRECTORY/.serverkit"
  [ -d "$TARGET" ] || continue
  echo "🧹 Cleaning $TARGET..."
  find "$TARGET" -type f -mtime +30 -print0 | xargs -r0 rm --
done
EOF
chmod +x /root/serverkit-cleanup.sh

# --- Cronjob diario de limpieza ---
echo "" | tee -a /etc/crontab
echo "# Serverkit Provisioning Cleanup" | tee -a /etc/crontab
tee -a /etc/crontab <<"CRONJOB"
0 0 * * * root bash /root/serverkit-cleanup.sh 2>&1
CRONJOB

# ===============================================
# Hostname, usuario y Git
# ===============================================

# --- Genera un hostname aleatorio para evitar conflictos ---
HOSTNAME="serverkit-$(openssl rand -hex 3)"
echo "$HOSTNAME" > /etc/hostname
sed -i "s/127\.0\.0\.1.*localhost/127.0.0.1\t$HOSTNAME.localdomain $HOSTNAME localhost/" /etc/hosts
hostname "$HOSTNAME"

# --- Genera contraseña aleatoria y la aplica al usuario ---
RAW_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-16)

ENCRYPTED_PASSWORD=$(mkpasswd -m sha-512 "$RAW_PASSWORD")
usermod --password "$ENCRYPTED_PASSWORD" serverkit

# --- Crea clave SSH para el usuario ---
ssh-keygen -f /home/serverkit/.ssh/id_rsa -t ed25519 -N ''
chown -R serverkit:serverkit /home/serverkit/.ssh
chmod 700 /home/serverkit/.ssh/id_rsa

# --- Agrega hosts de confianza ---
ssh-keyscan -H github.com >> /home/serverkit/.ssh/known_hosts
ssh-keyscan -H bitbucket.org >> /home/serverkit/.ssh/known_hosts
ssh-keyscan -H gitlab.com >> /home/serverkit/.ssh/known_hosts
chown serverkit:serverkit /home/serverkit/.ssh/known_hosts

# --- Configuración global de Git ---
git config --global user.name "Serverkit"
git config --global user.email "serverkit@localhost"

# ===============================================
# Firewall y actualizaciones automáticas
# ===============================================

# --- Detecta entorno AWS y ajusta firewall ---
if [ -z "${AWS_EXECUTION_ENV:-}" ]; then
  echo "🔐 Configurando firewall UFW local..."
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow 22
  ufw --force enable
else
  echo "⚙️ Detectado entorno Amazon EC2: omitiendo configuración de UFW (controlado por Security Group)."
fi

apt-get update -o Acquire::AllowReleaseInfoChange=true

# --- Configura actualizaciones automáticas ---
cat > /etc/apt/apt.conf.d/10periodic << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

# ===============================================
# Kernel y rotación de logs
# ===============================================

sysctl --system  # aplica parámetros del kernel

# --- Ajusta tamaño máximo de logs ---
for file in fail2ban rsyslog ufw; do
  conf="/etc/logrotate.d/$file"
  if [[ $(grep --count "maxsize" "$conf") == 0 ]]; then
    sed -i -r "s/^(\s*)(daily|weekly|monthly|yearly)$/\1\2\n\1maxsize 100M/" "$conf"
  else
    sed -i -r "s/^(\s*)maxsize.*$/\1maxsize 100M/" "$conf"
  fi
done

# --- Reconfigura logrotate.timer para correr cada hora ---
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

# --- Limpieza final ---
apt-get autoremove -y
apt-get clean

# ===============================================
# 🔚 Finalización
# ===============================================
touch /root/.serverkit-provisioned

echo
echo "==========================================="
IP=$(curl -s ifconfig.me || echo "desconocida")
echo
echo "✅ Servidor aprovisionado correctamente."
echo "Hostname: $HOSTNAME"
echo "Dirección IP pública: $IP"
echo "⚠️  IMPORTANTE: La contraseña se muestra solo UNA VEZ."
echo "Usuario: serverkit"
echo "Contraseña: $RAW_PASSWORD"
echo
echo "Copia y guarda esta contraseña ahora."
echo "Luego puedes limpiar la terminal con: history -c && clear"
echo "==========================================="
echo "=== Provisioning completed at $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG_FILE"