#!/usr/bin/env bash

# ===============================================
# Instalación de PostGIS 3
# ===============================================
# - Requiere PostgreSQL 18 instalado desde PGDG.
# - Instala PostGIS 3 y sus módulos.
# - No habilita extensiones automáticamente.
# - El usuario debe activarlas en la base de datos requerida.
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Iniciando instalación de PostGIS 3 para PostgreSQL 18..."

PG_VERSION="18"

# ---------------------------------------------------------------
# Validación: PostgreSQL 18 debe estar instalado
# ---------------------------------------------------------------
if ! command -v psql >/dev/null 2>&1; then
  echo "PostgreSQL no está instalado"
  exit 1
fi

if [[ ! -d "/etc/postgresql/${PG_VERSION}" ]]; then
  echo "No se encontró PostgreSQL ${PG_VERSION}. Abortando."
  exit 1
fi

# ---------------------------------------------------------------
# Actualizar paquetes
# ---------------------------------------------------------------
echo "Actualizando índices de paquetes..."
apt-get update -y -qq || {
  echo "Error ejecutando apt-get update"
  exit 1
}

# ---------------------------------------------------------------
# Instalar PostGIS 3
# ---------------------------------------------------------------
echo "Instalando PostGIS 3..."

apt-get install -y \
  postgis \
  postgresql-${PG_VERSION}-postgis-3 \
  postgresql-${PG_VERSION}-postgis-3-scripts || {
    echo "Error instalando PostGIS"
    exit 1
  }

# ---------------------------------------------------------------
# Resumen (incluye instrucciones para el usuario)
# ---------------------------------------------------------------
SERVERKIT_SUMMARY+="-------------------------------------------\n"
SERVERKIT_SUMMARY+="[PostGIS]\n"
SERVERKIT_SUMMARY+="PostGIS 3 instalado correctamente.\n"
SERVERKIT_SUMMARY+="Extensiones que debe habilitar en su base de datos:\n"
SERVERKIT_SUMMARY+="  CREATE EXTENSION postgis;\n"
SERVERKIT_SUMMARY+="  CREATE EXTENSION postgis_topology;\n"
SERVERKIT_SUMMARY+="  CREATE EXTENSION fuzzystrmatch;\n"
SERVERKIT_SUMMARY+="  CREATE EXTENSION postgis_raster;\n"
SERVERKIT_SUMMARY+="PostgreSQL versión: ${PG_VERSION}\n"
SERVERKIT_SUMMARY+="-------------------------------------------\n"

# ---------------------------------------------------------------
# Mostrar resumen si se ejecuta directamente
# ---------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo
  echo "==========================================="
  echo "PostGIS 3 instalado correctamente."
  echo "==========================================="
  echo -e "$SERVERKIT_SUMMARY"
fi