#!/usr/bin/env bash

# ===============================================
# Instalación de Node.js (via FNM)
# ===============================================
# Instala FNM, Node.js (LTS) y PNPM usando las rutas
# por defecto del usuario 'serverkit'.
# Configura automáticamente el entorno de shell.
# ===============================================

source /opt/serverkit/scripts/common/loader.sh

echo
echo "Iniciando instalación de Node.js y FNM..."

NODE_USER="serverkit"
NODE_HOME="/home/${NODE_USER}"
NODE_APPS="/opt/apps/node"
SHELL_RC="${NODE_HOME}/.bashrc"

# ---------------------------------------------------------------
# Validación de usuario
# ---------------------------------------------------------------
if ! id "$NODE_USER" &>/dev/null; then
  echo "Error: el usuario '${NODE_USER}' no existe. Debes crearlo antes de ejecutar este script."
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  SERVERKIT_SUMMARY+="[Node.js]\n"
  SERVERKIT_SUMMARY+="Error: usuario '${NODE_USER}' no encontrado. No se ejecutó la instalación.\n"
  SERVERKIT_SUMMARY+="-------------------------------------------\n"
  exit 1
fi

# ---------------------------------------------------------------
# Instalación de FNM, Node LTS y PNPM
# ---------------------------------------------------------------
sudo -u "$NODE_USER" bash <<'EOF'
set -e

# Instalar FNM si no existe
if ! command -v fnm >/dev/null 2>&1; then
  curl -fsSL https://fnm.vercel.app/install | bash >/dev/null 2>&1
fi

# Configurar entorno
export PATH="\$HOME/.local/share/fnm:\$PATH"
eval "\$(fnm env --shell bash)"

# Instalar Node.js LTS
fnm install --lts >/dev/null 2>&1
fnm default lts-latest >/dev/null 2>&1
fnm use default >/dev/null 2>&1

# Activar Corepack y PNPM
corepack enable >/dev/null 2>&1
corepack prepare pnpm@latest --activate >/dev/null 2>&1

echo "Node.js \$(node -v) — NPM \$(npm -v) — PNPM \$(pnpm -v)"
EOF

# ---------------------------------------------------------------
# Crear estructura base de aplicaciones Node
# ---------------------------------------------------------------
mkdir -p "$NODE_APPS"
chown -R "$NODE_USER":"$NODE_USER" "$NODE_APPS"
chmod 755 "$NODE_APPS"
echo "Directorio base para aplicaciones Node: ${NODE_APPS}"

# ---------------------------------------------------------------
# Configurar carga automática en shell
# ---------------------------------------------------------------
if ! grep -q 'fnm env' "$SHELL_RC"; then
  echo 'eval "$(fnm env --use-on-cd --shell bash)"' >> "$SHELL_RC"
  chown "$NODE_USER":"$NODE_USER" "$SHELL_RC"
  echo "Configuración de entorno FNM añadida en ${SHELL_RC}"
fi

# ---------------------------------------------------------------
# Validación final
# ---------------------------------------------------------------
NODE_VERSION=$(sudo -u "$NODE_USER" bash -c 'source ~/.bashrc >/dev/null 2>&1; node -v 2>/dev/null' || echo "N/A")
PNPM_VERSION=$(sudo -u "$NODE_USER" bash -c 'source ~/.bashrc >/dev/null 2>&1; pnpm -v 2>/dev/null' || echo "N/A")

if [[ "$NODE_VERSION" != "N/A" ]]; then
  echo "Node.js instalado correctamente."
  STATUS="instalado"
else
  echo "Error: no se pudo validar la instalación de Node.js."
  STATUS="error"
fi

# ---------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------
SERVERKIT_SUMMARY+="-------------------------------------------\n"
SERVERKIT_SUMMARY+="[Node.js]\n"
SERVERKIT_SUMMARY+="Estado: ${STATUS}\n"
SERVERKIT_SUMMARY+="Usuario: ${NODE_USER}\n"
SERVERKIT_SUMMARY+="Ruta: ${NODE_HOME}\n"
SERVERKIT_SUMMARY+="Aplicaciones: ${NODE_APPS}\n"
SERVERKIT_SUMMARY+="Node: ${NODE_VERSION}\n"
SERVERKIT_SUMMARY+="PNPM: ${PNPM_VERSION}\n"
SERVERKIT_SUMMARY+="-------------------------------------------\n"

# ---------------------------------------------------------------
# Mostrar resumen si se ejecuta directamente
# ---------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo
  echo "==========================================="
  echo "Node.js instalado correctamente."
  echo "==========================================="
  echo -e "$SERVERKIT_SUMMARY"
  echo
fi