#!/usr/bin/env bash

# ===============================================
# Desinstalación completa de PostgreSQL 18
# ===============================================
# - Detiene y deshabilita PostgreSQL.
# - Elimina paquetes postgresql-18 y dependencias.
# - Remueve directorios de configuración y datos.
# - Elimina repositorio PGDG si fue instalado.
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Iniciando desinstalación de PostgreSQL 18..."

PG_VERSION="18"
PG_CONF_DIR="/etc/postgresql/${PG_VERSION}"
PG_DATA_DIR="/var/lib/postgresql/${PG_VERSION}"
PG_LOG_DIR="/var/log/postgresql"
PGDG_LIST="/etc/apt/sources.list.d/pgdg.list"

# ---------------------------------------------------------------
# Detener servicio si existe
# ---------------------------------------------------------------
echo "Deteniendo servicio PostgreSQL..."
systemctl stop postgresql
systemctl disable postgresql

# ---------------------------------------------------------------
# Remover paquetes PostgreSQL 18
# ---------------------------------------------------------------
echo "Eliminando paquetes de PostgreSQL 18..."

apt-get purge -y \
  postgresql-18 \
  postgresql-client-18 \
  postgresql-contrib-18

# Remover metapaquete (si lo instaló Ubuntu)
apt-get purge -y postgresql

# Limpiar dependencias huérfanas
apt-get autoremove -y

# ---------------------------------------------------------------
# Eliminar archivos y directorios de configuración/datos
# ---------------------------------------------------------------
echo "Eliminando directorios de configuración y datos..."

rm -rf "$PG_CONF_DIR"
rm -rf "$PG_DATA_DIR"
rm -rf "$PG_LOG_DIR"

# ---------------------------------------------------------------
# Eliminar repositorio PGDG
# ---------------------------------------------------------------
if [[ -f "$PGDG_LIST" ]]; then
  echo "Eliminando repositorio PGDG..."
  rm -f "$PGDG_LIST"
fi

# ---------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------
SERVERKIT_SUMMARY+="-------------------------------------------\n"
SERVERKIT_SUMMARY+="[PostgreSQL ${PG_VERSION} - Desinstalación]\n"
SERVERKIT_SUMMARY+="Servicio detenido y deshabilitado.\n"
SERVERKIT_SUMMARY+="Paquetes PostgreSQL ${PG_VERSION} eliminados.\n"
SERVERKIT_SUMMARY+="Directorios de configuración y datos eliminados.\n"
SERVERKIT_SUMMARY+="Repositorio PGDG eliminado.\n"
SERVERKIT_SUMMARY+="Usuario SQL 'serverkit' eliminado.\n"
SERVERKIT_SUMMARY+="-------------------------------------------\n"

# ---------------------------------------------------------------
# Mostrar resumen si se ejecuta directamente
# ---------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo
  echo "==========================================="
  echo "PostgreSQL 18 eliminado correctamente."
  echo "==========================================="
  echo -e "$SERVERKIT_SUMMARY"
fi