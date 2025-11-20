#!/usr/bin/env bash

# ===============================================
# Desinstalación de componentes Python 3
# ===============================================
# - No elimina python3 (es parte crítica del sistema).
# - Elimina pip, venv, dev y build-essentialt.
# - Limpia dependencias huérfanas.
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Iniciando desinstalación de componentes Python 3..."

# ---------------------------------------------------------------
# Remover paquetes
# ---------------------------------------------------------------
apt-get purge -y \
  python3-pip \
  python3-venv \
  python3-dev \
  build-essential || {
    echo "Error eliminando paquetes Python"
    exit 1
  }

# ---------------------------------------------------------------
# Limpiar dependencias
# ---------------------------------------------------------------
apt-get autoremove -y || true

# ---------------------------------------------------------------
# Verificación de Python
# ---------------------------------------------------------------
if command -v python3 >/dev/null 2>&1; then
  PY_STATUS="Python 3 sigue disponible"
else
  PY_STATUS="python3 no disponible"
fi

# ---------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------
SERVERKIT_SUMMARY+="-------------------------------------------\n"
SERVERKIT_SUMMARY+="[Python - Desinstalación]\n"
SERVERKIT_SUMMARY+="Paquetes pip/venv/dev eliminados.\n"
SERVERKIT_SUMMARY+="Dependencias huérfanas limpiadas.\n"
SERVERKIT_SUMMARY+="Estado de python3: ${PY_STATUS}\n"
SERVERKIT_SUMMARY+="-------------------------------------------\n"

# ---------------------------------------------------------------
# Mostrar resumen si se ejecuta directamente
# ---------------------------------------------------------------
if [[ \"${BASH_SOURCE[0]}\" == \"${0}\" ]]; then
  echo
  echo "==========================================="
  echo "Componentes Python eliminados correctamente."
  echo "==========================================="
  echo -e "$SERVERKIT_SUMMARY"
fi