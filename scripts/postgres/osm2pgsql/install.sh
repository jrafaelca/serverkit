#!/usr/bin/env bash

# ===============================================
# Instalación de osm2pgsql
# ===============================================
# - Instala osm2pgsql desde los repos de Ubuntu/PGDG.
# - Verifica binario y muestra versión.
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Iniciando instalación de osm2pgsql..."

# ---------------------------------------------------------------
# Actualizar paquetes
# ---------------------------------------------------------------
apt-get update -y -qq || {
  echo "Error ejecutando apt-get update"
  exit 1
}

# ---------------------------------------------------------------
# Instalar osm2pgsql
# ---------------------------------------------------------------
apt-get install -y osm2pgsql || {
  echo "Error instalando osm2pgsql"
  exit 1
}

# ---------------------------------------------------------------
# Validación final
# ---------------------------------------------------------------
if ! command -v osm2pgsql >/dev/null 2>&1; then
  echo "El binario osm2pgsql no se encuentra en el sistema"
  exit 1
fi

OSM2PGSQL_VERSION=$(osm2pgsql --version 2>/dev/null | head -n1)

# ---------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------
SERVERKIT_SUMMARY+="-------------------------------------------\n"
SERVERKIT_SUMMARY+="[osm2pgsql]\n"
SERVERKIT_SUMMARY+="Instalado correctamente.\n"
SERVERKIT_SUMMARY+="Versión detectada: ${OSM2PGSQL_VERSION}\n"
SERVERKIT_SUMMARY+="Binario: $(command -v osm2pgsql)\n"
SERVERKIT_SUMMARY+="-------------------------------------------\n"

# ---------------------------------------------------------------
# Mostrar resumen si se ejecuta directamente
# ---------------------------------------------------------------
if [[ \"${BASH_SOURCE[0]}\" == \"${0}\" ]]; then
  echo
  echo "==========================================="
  echo "osm2pgsql instalado correctamente."
  echo "==========================================="
  echo -e "$SERVERKIT_SUMMARY"
fi