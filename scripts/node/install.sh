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
PROFILE_RC="${NODE_HOME}/.profile"

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

if ! command -v fnm >/dev/null 2>&1; then
  echo "Instalando FNM..."
  curl -fsSL https://fnm.vercel.app/install | bash >/dev/null 2>&1
fi

export PATH="\$HOME/.local/share/fnm:\$PATH"
eval "\$(fnm env --shell bash)"

fnm install --lts >/dev/null 2>&1
fnm default lts-latest >/dev/null 2>&1
fnm use default >/dev/null 2>&1

corepack enable >/dev/null 2>&1
corepack prepare pnpm@latest --activate >/dev/null 2>&1

echo "Node.js \$(node -v) — NPM \$(npm -v) — PNPM \$(pnpm -v)"
EOF

# ---------------------------------------------------------------
# Configurar carga automática en shell (bashrc y profile)
# ---------------------------------------------------------------
CONFIG_BLOCK=$(cat <<'EOT'

# Cargar entorno FNM en cualquier sesión
if [ -s "$HOME/.local/share/fnm" ]; then
  export PATH="$HOME/.local/share/fnm:$PATH"
  eval "$(fnm env --use-on-cd --shell bash)"
fi
EOT
)

for FILE in "$SHELL_RC" "$PROFILE_RC"; do
  if ! grep -q 'fnm env' "$FILE" 2>/dev/null; then
    echo "$CONFIG_BLOCK" >> "$FILE"
    chown "$NODE_USER":"$NODE_USER" "$FILE"
    echo "Configuración de entorno FNM añadida en ${FILE}"
  fi
done

# ---------------------------------------------------------------
# Crear estructura base de aplicaciones Node
# ---------------------------------------------------------------
mkdir -p "$NODE_APPS"
chown -R "$NODE_USER":"$NODE_USER" "$NODE_APPS"
chmod 755 "$NODE_APPS"
echo "Directorio base para aplicaciones Node: ${NODE_APPS}"

# ---------------------------------------------------------------
# Validación final usando entorno real del usuario
# ---------------------------------------------------------------
NODE_VERSION=$(sudo -u "$NODE_USER" bash -lc "node -v 2>/dev/null" || echo "N/A")
PNPM_VERSION=$(sudo -u "$NODE_USER" bash -lc "pnpm -v 2>/dev/null" || echo "N/A")

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
  echo -e "$SERVERKIT_SUMMARY"
fi