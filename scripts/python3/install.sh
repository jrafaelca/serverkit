#!/usr/bin/env bash

# ===============================================
# Instalación de Python 3 y herramientas básicas
# ===============================================
# - Usa Python 3 del sistema (Ubuntu 24.04 trae 3.12)
# - Instala python3-pip, python3-venv y módulos esenciales
# - Verifica versión
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Iniciando instalación de Python 3..."

# ---------------------------------------------------------------
# Actualizar repos
# ---------------------------------------------------------------
apt-get update -y -qq || {
  echo "Error ejecutando apt-get update"
  exit 1
}

# ---------------------------------------------------------------
# Instalar paquetes Python requeridos
# ---------------------------------------------------------------
apt-get install -y \
  python3 \
  python3-pip \
  python3-venv \
  python3-dev \
  build-essential || {
    echo "Error instalando Python 3"
    exit 1
  }

# ---------------------------------------------------------------
# Validar Python
# ---------------------------------------------------------------
PY_VERSION=$(python3 --version 2>/dev/null)

if [[ -z "$PY_VERSION" ]]; then
  echo "Error: python3 no se encuentra en el sistema"
  exit 1
fi

# ---------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------
SERVERKIT_SUMMARY+="-------------------------------------------\n"
SERVERKIT_SUMMARY+="[Python]\n"
SERVERKIT_SUMMARY+="Python instalado correctamente.\n"
SERVERKIT_SUMMARY+="Versión detectada: ${PY_VERSION}\n"
SERVERKIT_SUMMARY+="pip3 disponible en: $(command -v pip3)\n"
SERVERKIT_SUMMARY+="-------------------------------------------\n"

# ---------------------------------------------------------------
# Mostrar resumen si se ejecuta directamente
# ---------------------------------------------------------------
if [[ \"${BASH_SOURCE[0]}\" == \"${0}\" ]]; then
  echo
  echo "==========================================="
  echo "Python 3 instalado correctamente."
  echo "==========================================="
  echo -e "$SERVERKIT_SUMMARY"
fi