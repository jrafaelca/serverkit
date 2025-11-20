#!/usr/bin/env bash

# ===============================================
# Desinstalación de PostGIS 3
# ===============================================
# - Requiere PostgreSQL 18 instalado.
# - Elimina PostGIS 3 y módulos relacionados.
# - No elimina bases de datos ni extensiones habilitadas.
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Iniciando desinstalación de PostGIS 3..."

PG_VERSION="18"

# ---------------------------------------------------------------
# Validación de PostgreSQL
# ---------------------------------------------------------------
if ! command -v psql >/dev/null 2>&1; then
  echo "PostgreSQL no está instalado. Abortando."
  exit 1
fi

if [[ ! -d "/etc/postgresql/${PG_VERSION}" ]]; then
  echo "No se encontró PostgreSQL ${PG_VERSION}. Abortando."
  exit 1
fi

# ---------------------------------------------------------------
# Remover paquetes PostGIS
# ---------------------------------------------------------------
echo "Eliminando paquetes PostGIS..."

apt-get purge -y \
  postgis \
  postgresql-${PG_VERSION}-postgis-3 \
  postgresql-${PG_VERSION}-postgis-3-scripts || {
    echo "Error eliminando paquetes de PostGIS"
    exit 1
  }

# Limpiar dependencias huérfanas
apt-get autoremove -y >/dev/null 2>&1

# ---------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------
SERVERKIT_SUMMARY+="-------------------------------------------\n"
SERVERKIT_SUMMARY+="[PostGIS - Desinstalación]\n"
SERVERKIT_SUMMARY+="PostGIS 3 y módulos asociados eliminados.\n"
SERVERKIT_SUMMARY+="PostgreSQL versión detectada: ${PG_VERSION}\n"
SERVERKIT_SUMMARY+="Nota: Las extensiones dentro de las bases de datos permanecen.\n"
SERVERKIT_SUMMARY+="Para eliminarlas:\n"
SERVERKIT_SUMMARY+="  DROP EXTENSION postgis;\n"
SERVERKIT_SUMMARY+="  DROP EXTENSION postgis_topology;\n"
SERVERKIT_SUMMARY+="  DROP EXTENSION fuzzystrmatch;\n"
SERVERKIT_SUMMARY+="  DROP EXTENSION postgis_raster;\n"
SERVERKIT_SUMMARY+="-------------------------------------------\n"

# ---------------------------------------------------------------
# Mostrar resumen si se ejecuta directamente
# ---------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo
  echo "==========================================="
  echo "PostGIS 3 eliminado correctamente."
  echo "==========================================="
  echo -e "$SERVERKIT_SUMMARY"
fi