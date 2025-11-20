#!/usr/bin/env bash

# ===============================================
# Desinstalación de osm2pgsql
# ===============================================
# - Elimina paquete osm2pgsql.
# - Limpia dependencias huérfanas.
# - Verifica que el binario fue removido.
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Iniciando desinstalación de osm2pgsql..."

PACKAGE="osm2pgsql"

# ---------------------------------------------------------------
# Verificar si está instalado
# ---------------------------------------------------------------
if ! dpkg -l | grep -q "^ii  ${PACKAGE}"; then
  echo "osm2pgsql no está instalado. No hay nada que desinstalar."
  exit 0
fi

# ---------------------------------------------------------------
# Eliminar paquete osm2pgsql
# ---------------------------------------------------------------
echo "Eliminando paquete osm2pgsql..."

apt-get purge -y ${PACKAGE} || {
  echo "Error eliminando osm2pgsql"
  exit 1
}

# ---------------------------------------------------------------
# Limpiar dependencias huérfanas
# ---------------------------------------------------------------
echo "Limpiando dependencias no utilizadas..."
apt-get autoremove -y || true

# ---------------------------------------------------------------
# Validar desinstalación
# ---------------------------------------------------------------
if command -v osm2pgsql >/dev/null 2>&1; then
  STATUS="binario aún presente en el sistema"
else
  STATUS="eliminado"
fi

# ---------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------
SERVERKIT_SUMMARY+="-------------------------------------------\n"
SERVERKIT_SUMMARY+="[osm2pgsql - Desinstalación]\n"
SERVERKIT_SUMMARY+="Paquete eliminado.\n"
SERVERKIT_SUMMARY+="Dependencias huérfanas limpiadas.\n"
SERVERKIT_SUMMARY+="Estado del binario: ${STATUS}\n"
SERVERKIT_SUMMARY+="-------------------------------------------\n"

# ---------------------------------------------------------------
# Mostrar resumen si se ejecuta directamente
# ---------------------------------------------------------------
if [[ \"${BASH_SOURCE[0]}\" == \"${0}\" ]]; then
  echo
  echo "==========================================="
  echo "osm2pgsql eliminado correctamente."
  echo "==========================================="
  echo -e "$SERVERKIT_SUMMARY"
fi