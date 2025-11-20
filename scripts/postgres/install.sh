#!/usr/bin/env bash

# ===============================================
# Instalación y Endurecimiento de PostgreSQL 18
# (Usando repositorio oficial PGDG)
# ===============================================
# - Configura repositorio PGDG (método oficial).
# - Instala PostgreSQL 18.
# - Hardening: solo localhost + scram-sha-256.
# - Logging con rotación nativa PG (1 día / 100MB).
# - Performance básico seguro.
# - Crea usuario SQL 'serverkit' con contraseña aleatoria.
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Iniciando instalación de PostgreSQL 18..."

PG_VERSION="18"
PG_CONF="/etc/postgresql/18/main/postgresql.conf"
PG_HBA="/etc/postgresql/${PG_VERSION}/main/pg_hba.conf"

# ---------------------------------------------------------------
# Instalar postgresql-common (incluye script PGDG oficial)
# ---------------------------------------------------------------
echo "Instalando postgresql-common y configurando repositorio PGDG..."

apt-get update -y -qq
apt-get install -y -qq postgresql-common || {
  echo "Error: no se pudo instalar postgresql-common."
  exit 1
}

# Ejecutar script oficial PGDG si el repo aún no existe
if [[ ! -f /etc/apt/sources.list.d/pgdg.list ]]; then
  echo "Ejecutando script oficial de configuración PGDG..."
  bash /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y || {
    echo "Error configurando repositorio PGDG."
    exit 1
  }
else
  echo "Repositorio PGDG ya existe. Omitiendo configuración."
fi

# ---------------------------------------------------------------
# Instalar PostgreSQL 18
# ---------------------------------------------------------------
PG_VERSION="18"

echo "Instalando PostgreSQL ${PG_VERSION}..."

apt-get update -y -qq
apt-get install -y -qq \
  postgresql-${PG_VERSION} \
  postgresql-client-${PG_VERSION} \
  postgresql-contrib || {
    echo "Error: no se pudo instalar PostgreSQL ${PG_VERSION}."
    exit 1
  }

# ---------------------------------------------------------------
# Hardening: solo escuchar en localhost
# ---------------------------------------------------------------
echo "Aplicando hardening de conexión..."

sed -i "s/^#listen_addresses =.*/listen_addresses = 'localhost'/" "$PG_CONF"

# pg_hba.conf seguro
cat > "$PG_HBA" <<EOF
# Hardened by ServerKit
local   all             postgres                                peer
local   all             all                                     scram-sha-256
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             ::1/128                 scram-sha-256
EOF

# ---------------------------------------------------------------
# Logging con rotación nativa PostgreSQL
# ---------------------------------------------------------------
echo "Configurando logging con rotación nativa..."

sed -i "s/^#logging_collector =.*/logging_collector = on/" "$PG_CONF"
sed -i "s/^#log_directory =.*/log_directory = 'log'/" "$PG_CONF"
sed -i "s/^#log_filename =.*/log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'/" "$PG_CONF"
sed -i "s/^#log_truncate_on_rotation =.*/log_truncate_on_rotation = on/" "$PG_CONF"
sed -i "s/^#log_rotation_age =.*/log_rotation_age = 1d/" "$PG_CONF"
sed -i "s/^#log_rotation_size =.*/log_rotation_size = 100MB/" "$PG_CONF"

# Logging útil
sed -i "s/^#log_connections =.*/log_connections = on/" "$PG_CONF"
sed -i "s/^#log_disconnections =.*/log_disconnections = on/" "$PG_CONF"
sed -i "s/^#log_min_duration_statement =.*/log_min_duration_statement = 1000/" "$PG_CONF"

# ---------------------------------------------------------------
# Performance inicial seguro
# ---------------------------------------------------------------
echo "Aplicando configuración básica de rendimiento..."

sed -i "s/^[#[:space:]]*shared_buffers.*/shared_buffers = 512MB/" "$PG_CONF"
sed -i "s/^[#[:space:]]*work_mem.*/work_mem = 16MB/" "$PG_CONF"
sed -i "s/^[#[:space:]]*maintenance_work_mem.*/maintenance_work_mem = 256MB/" "$PG_CONF"
sed -i "s/^[#[:space:]]*effective_cache_size.*/effective_cache_size = 2GB/" "$PG_CONF"
sed -i "s/^[#[:space:]]*max_connections.*/max_connections = 100/" "$PG_CONF"

# ---------------------------------------------------------------
# Iniciar servicio
# ---------------------------------------------------------------
echo "Habilitando y arrancando servicio PostgreSQL..."
systemctl enable --now postgresql >/dev/null 2>&1
sleep 2

STATUS="error"
if systemctl is-active --quiet postgresql; then
  STATUS="activo"
fi

# ---------------------------------------------------------------
# Crear usuario SQL serverkit con contraseña aleatoria
# ---------------------------------------------------------------
echo "Creando usuario SQL 'serverkit'..."

DB_USER="serverkit"
DB_NAME="serverkit"

DB_PASS=$(openssl rand -base64 16 | tr -d '/+=' | cut -c1-16)

sudo -u postgres psql <<EOF
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${DB_USER}') THEN
        CREATE ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASS}' NOSUPERUSER INHERIT;
    END IF;
END
\$\$;

CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};
EOF

# ---------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------
SERVERKIT_SUMMARY+="-------------------------------------------\n"
SERVERKIT_SUMMARY+="[PostgreSQL ${PG_VERSION}]\n"
SERVERKIT_SUMMARY+="Estado del servicio : ${STATUS}\n"
SERVERKIT_SUMMARY+="Puerto              : 5432\n"
SERVERKIT_SUMMARY+="Hardening           : Escucha solo en localhost\n"
SERVERKIT_SUMMARY+="Auth                : scram-sha-256\n"
SERVERKIT_SUMMARY+="Logging             : Rotación nativa PG (1 día / 100MB)\n"
SERVERKIT_SUMMARY+="Performance         : Ajustes básicos aplicados\n"
SERVERKIT_SUMMARY+="\n"
SERVERKIT_SUMMARY+="[Usuario inicial]\n"
SERVERKIT_SUMMARY+="Usuario SQL : ${DB_USER}\n"
SERVERKIT_SUMMARY+="Base de datos: ${DB_NAME}\n"
SERVERKIT_SUMMARY+="Contraseña   : ${DB_PASS}\n"
SERVERKIT_SUMMARY+="-------------------------------------------\n"

# ---------------------------------------------------------------
# Mostrar resumen si se ejecuta directamente
# ---------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo
  echo "==========================================="
  echo "PostgreSQL ${PG_VERSION} instalado, endurecido y configurado."
  echo "==========================================="
  echo -e "$SERVERKIT_SUMMARY"
fi