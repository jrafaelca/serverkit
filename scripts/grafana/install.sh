#!/usr/bin/env bash

# ===============================================
# Instalación de Grafana OSS (Open Source)
# ===============================================
# Instala Grafana OSS desde el repositorio oficial
# de Grafana Labs en Ubuntu. Crea el usuario admin
# 'serverkit' con una contraseña aleatoria efímera
# y configura el servicio systemd.
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Iniciando instalación de Grafana OSS..."

CONFIG_FILE="/etc/grafana/grafana.ini"
ADMIN_USER="serverkit"
ADMIN_PASS=$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-16)
GPG_KEYRING="/etc/apt/keyrings/grafana.gpg"
REPO_LIST="/etc/apt/sources.list.d/grafana.list"

# ---------------------------------------------------------------
# Instalar dependencias base
# ---------------------------------------------------------------
echo "Instalando dependencias base..."
apt-get update -y -qq
apt-get install -y -qq apt-transport-https software-properties-common wget gpg || {
  echo "Error: no se pudieron instalar dependencias base."
  exit 1
}

# ---------------------------------------------------------------
# Agregar repositorio oficial de Grafana Labs
# ---------------------------------------------------------------
echo "Agregando repositorio oficial de Grafana..."
mkdir -p /etc/apt/keyrings/
if [[ ! -f "$GPG_KEYRING" ]]; then
  wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | tee "$GPG_KEYRING" >/dev/null
  echo "deb [signed-by=${GPG_KEYRING}] https://apt.grafana.com stable main" > "$REPO_LIST"
else
  echo "Repositorio de Grafana ya configurado, omitiendo."
fi

# ---------------------------------------------------------------
# Instalar Grafana OSS
# ---------------------------------------------------------------
apt-get update -y -qq
if ! dpkg -l | grep -q grafana; then
  echo "Instalando Grafana OSS..."
  apt-get install -y -qq grafana
  echo "Grafana OSS instalado correctamente."
else
  echo "Grafana OSS ya está instalado. Omitiendo."
fi

# ---------------------------------------------------------------
# Configuración base de Grafana
# ---------------------------------------------------------------
echo "Aplicando configuración base..."
if [[ -f "$CONFIG_FILE" ]]; then
  sed -i "s/^;http_port = .*/http_port = 3000/" "$CONFIG_FILE"
  sed -i "s/^;allow_sign_up = .*/allow_sign_up = false/" "$CONFIG_FILE"
  sed -i "s/^;admin_user = .*/admin_user = ${ADMIN_USER}/" "$CONFIG_FILE"
  sed -i "s/^;admin_password = .*/admin_password = ${ADMIN_PASS}/" "$CONFIG_FILE"
else
  cat > "$CONFIG_FILE" <<EOF
[server]
http_port = 3000

[security]
allow_sign_up = false
admin_user = ${ADMIN_USER}
admin_password = ${ADMIN_PASS}
EOF
fi

chown -R grafana:grafana /etc/grafana
chmod 640 "$CONFIG_FILE"

# ---------------------------------------------------------------
# Habilitar e iniciar Grafana
# ---------------------------------------------------------------
echo "Habilitando y arrancando servicio grafana-server..."
systemctl daemon-reload >/dev/null 2>&1
systemctl enable --now grafana-server >/dev/null 2>&1
sleep 3

# ---------------------------------------------------------------
# Validación final
# ---------------------------------------------------------------
if systemctl is-active --quiet grafana-server; then
  echo "Grafana OSS iniciado correctamente."
  STATUS="activo"
else
  echo "Advertencia: el servicio grafana-server no se inició correctamente."
  STATUS="error"
fi

# ---------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------
SERVERKIT_SUMMARY+="-------------------------------------------\n"
SERVERKIT_SUMMARY+="[Grafana OSS]\n"
SERVERKIT_SUMMARY+="Estado del servicio: ${STATUS}\n"
SERVERKIT_SUMMARY+="Usuario admin: ${ADMIN_USER}\n"
SERVERKIT_SUMMARY+="Contraseña efímera: ${ADMIN_PASS}\n"
SERVERKIT_SUMMARY+="Puerto: 3000\n"
SERVERKIT_SUMMARY+="URL de acceso: http://$(hostname -I | awk '{print $1}'):3000\n"
SERVERKIT_SUMMARY+="Nota: la contraseña no se guarda en disco, solo se muestra una vez.\n"
SERVERKIT_SUMMARY+="-------------------------------------------\n"

# ---------------------------------------------------------------
# Mostrar resumen en ejecución directa
# ---------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo
  echo "==========================================="
  echo "Grafana OSS instalado correctamente."
  echo "==========================================="
  echo "Usuario admin : ${ADMIN_USER}"
  echo "Contraseña     : ${ADMIN_PASS}"
  echo "Puerto         : 3000"
  echo "URL acceso     : http://$(hostname -I | awk '{print $1}'):3000"
  echo "-------------------------------------------"
  echo "Guarda esta contraseña ahora. No se volverá a mostrar."
  echo "==========================================="
  echo
  echo -e "$SERVERKIT_SUMMARY"
fi