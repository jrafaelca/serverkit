#!/usr/bin/env bash

# ===============================================
# Desinstalación de Node.js (via FNM)
# ===============================================
# Elimina FNM, Node.js y PNPM del usuario 'serverkit'
# sin afectar configuraciones globales del sistema.
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Iniciando desinstalación de Node.js y FNM..."

NODE_USER="serverkit"
NODE_HOME="/home/${NODE_USER}"
FNM_PATH="${NODE_HOME}/.local/share/fnm"
SHELL_RC="${NODE_HOME}/.bashrc"

# ---------------------------------------------------------------
# Validar usuario
# ---------------------------------------------------------------
if ! id "$NODE_USER" &>/dev/null; then
  echo "Error: el usuario '${NODE_USER}' no existe."
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Node.js]\n"
  SERVERKIT_SUMMARY+="Error: el usuario '${NODE_USER}' no existe.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  exit 1
fi

# ---------------------------------------------------------------
# Finalizar procesos asociados a Node.js
# ---------------------------------------------------------------
pkill -u "$NODE_USER" node 2>/dev/null || true
pkill -u "$NODE_USER" pm2 2>/dev/null || true
echo "Procesos de Node.js terminados."

# ---------------------------------------------------------------
# Eliminar archivos locales de FNM, Node.js y PNPM
# ---------------------------------------------------------------
sudo -u "$NODE_USER" bash <<'EOF'
rm -rf ~/.fnm
rm -rf ~/.local/share/fnm
rm -rf ~/.cache/{node,npm,fnm}
EOF
echo "Archivos de entorno Node.js eliminados."

# ---------------------------------------------------------------
# Eliminar configuración de FNM en el shell
# ---------------------------------------------------------------
if grep -q 'fnm env' "$SHELL_RC"; then
  sed -i '/fnm env/d' "$SHELL_RC" 2>/dev/null || true
  echo "Entradas de FNM eliminadas de ${SHELL_RC}."
fi

# ---------------------------------------------------------------
# Validación final
# ---------------------------------------------------------------
if [[ ! -d "$FNM_PATH" ]] && ! sudo -u "$NODE_USER" bash -c 'command -v node >/dev/null 2>&1'; then
  echo "Node.js desinstalado correctamente."
  STATUS="desinstalado"
else
  echo "Advertencia: algunos archivos o comandos de Node.js podrían persistir."
  STATUS="parcial"
fi

# ---------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------
SERVERKIT_SUMMARY+="-------------------------------------------\n"
SERVERKIT_SUMMARY+="[Node.js]\n"
SERVERKIT_SUMMARY+="Estado: ${STATUS}\n"
SERVERKIT_SUMMARY+="Usuario: ${NODE_USER}\n"
SERVERKIT_SUMMARY+="Ruta home: ${NODE_HOME}\n"
SERVERKIT_SUMMARY+="Archivos eliminados: ~/.fnm, ~/.local/share/fnm, ~/.cache/{node,npm,fnm}\n"
SERVERKIT_SUMMARY+="-------------------------------------------\n"

# ---------------------------------------------------------------
# Mostrar resumen si se ejecuta directamente
# ---------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo
  echo "==========================================="
  echo "Desinstalación de Node.js completada."
  echo "==========================================="
  echo -e "$SERVERKIT_SUMMARY"
  echo
fi