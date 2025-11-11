#!/usr/bin/env bash

# ===============================================
# Inicialización principal de ServerKit
# ===============================================

set -euo pipefail

# Carga el entorno base
source /opt/serverkit/scripts/common/loader.sh

echo
echo "Iniciando proceso de aprovisionamiento base..."
echo "============================================================"

# Verificar si el sistema ya fue aprovisionado previamente
if [[ -f /opt/serverkit/.provisioned ]]; then
  echo "El sistema ya fue aprovisionado anteriormente."
  echo "Si desea repetir el proceso, elimine /opt/serverkit/.provisioned y vuelva a ejecutar este script."
  exit 0
fi

SERVERKIT_SUMMARY+="===========================================\n"
SERVERKIT_SUMMARY+="Servidor aprovisionado correctamente.\n"

# Crear usuario administrativo y preparar su entorno
echo
echo "Creando usuario administrativo..."
source /opt/serverkit/scripts/serverkit/setup-user.sh

# Configurar tareas automáticas de limpieza
echo
echo "Configurando tareas automáticas de limpieza..."
source /opt/serverkit/scripts/serverkit/setup-cleaner.sh

# Instalar y configurar parámetros del sistema base
echo
echo "Configurando parámetros básicos del sistema..."
source /opt/serverkit/scripts/system/setup-system.sh

# Configurar SSH con seguridad endurecida
echo
echo "Endureciendo configuración SSH..."
source /opt/serverkit/scripts/system/setup-ssh.sh

# Configurar el uso de memoria swap
echo
echo "Configurando memoria swap..."
source /opt/serverkit/scripts/system/setup-swap.sh

# Establecer la zona horaria del sistema
echo
echo "Ajustando zona horaria del sistema..."
source /opt/serverkit/scripts/system/setup-timezone.sh

# Instalar y configurar Logrotate
echo
echo "Instalando y configurando Logrotate..."
source /opt/serverkit/scripts/logrotate/install.sh

# Instalar y habilitar Fail2Ban
echo
echo "Instalando y habilitando Fail2Ban..."
source /opt/serverkit/scripts/fail2ban/install.sh

# Marcar el sistema como aprovisionado
touch /opt/serverkit/.provisioned

SERVERKIT_SUMMARY+="-------------------------------------------\n"
SERVERKIT_SUMMARY+="Servidor aprovisionado correctamente.\n"
SERVERKIT_SUMMARY+="Hostname: $(hostname)\n"
SERVERKIT_SUMMARY+="Fecha de finalización: $(date '+%Y-%m-%d %H:%M:%S')\n"
SERVERKIT_SUMMARY+="-------------------------------------------\n"
SERVERKIT_SUMMARY+="Para limpiar el historial ejecuta:\n"
SERVERKIT_SUMMARY+="  history -c && history -w && rm -f ~/.bash_history\n"
SERVERKIT_SUMMARY+="===========================================\n"

# Mostrar resumen final
echo -e "$SERVERKIT_SUMMARY"