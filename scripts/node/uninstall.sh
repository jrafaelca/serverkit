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
FNM_DIR="${NODE_HOME}/.local/share/fnm"
CACHE_DIR="${NODE_HOME}/.cache"
SHELL_RC="${NODE_HOME}/.bashrc"
PROFILE_RC="${NODE_HOME}/.profile"

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
# Verificar procesos activos Node.js
# ---------------------------------------------------------------
if pgrep -u "$NODE_USER" node >/dev/null 2>&1 || pgrep -u "$NODE_USER" pm2 >/dev/null 2>&1; then
  echo "Se detectaron procesos Node.js activos del usuario '${NODE_USER}'."
  ps -u "$NODE_USER" -o pid,cmd | grep node
  echo
  read -rp "¿Deseas detenerlos antes de continuar? (y/n): " CONFIRM
  if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
    pkill -u "$NODE_USER" node 2>/dev/null || true
    pkill -u "$NODE_USER" pm2 2>/dev/null || true
    echo "Procesos Node.js detenidos."
  else
    echo "Continuando sin detener procesos activos (pueden dejar archivos bloqueados)."
  fi
fi

# ---------------------------------------------------------------
# Eliminar archivos locales de FNM, Node.js y PNPM
# ---------------------------------------------------------------
sudo -u "$NODE_USER" bash <<'EOF'
set -e
rm -rf ~/.fnm 2>/dev/null || true
rm -rf ~/.local/share/fnm 2>/dev/null || true
rm -rf ~/.cache/{node,npm,fnm} 2>/dev/null || true
EOF
echo "Archivos locales de Node.js eliminados."

# ---------------------------------------------------------------
# Eliminar configuración de FNM en el shell (.bashrc y .profile)
# ---------------------------------------------------------------
for FILE in "$SHELL_RC" "$PROFILE_RC"; do
  if [[ -f "$FILE" ]]; then
    sed -i '/fnm env/d' "$FILE" 2>/dev/null || true
    sed -i '/\.local\/share\/fnm/d' "$FILE" 2>/dev/null || true
    echo "Entradas de FNM eliminadas de ${FILE}."
  fi
done

# ---------------------------------------------------------------
# Validación final
# ---------------------------------------------------------------
NODE_EXISTS=$(sudo -u "$NODE_USER" bash -c 'command -v node >/dev/null 2>&1 && echo yes || echo no')
FNM_EXISTS=$(sudo -u "$NODE_USER" bash -c 'command -v fnm >/dev/null 2>&1 && echo yes || echo no')

if [[ "$NODE_EXISTS" == "no" && "$FNM_EXISTS" == "no" && ! -d "$FNM_DIR" ]]; then
  STATUS="desinstalado"
  echo "Node.js y FNM desinstalados correctamente."
else
  STATUS="parcial"
  echo "Advertencia: algunos binarios o configuraciones podrían persistir."
fi

# ---------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------
SERVERKIT_SUMMARY+="-------------------------------------------\n"
SERVERKIT_SUMMARY+="[Node.js]\n"
SERVERKIT_SUMMARY+="Estado: ${STATUS}\n"
SERVERKIT_SUMMARY+="Usuario: ${NODE_USER}\n"
SERVERKIT_SUMMARY+="Ruta home: ${NODE_HOME}\n"
SERVERKIT_SUMMARY+="Archivos eliminados: ~/.local/share/fnm, ~/.cache/{node,npm,fnm}\n"
SERVERKIT_SUMMARY+="Configuración removida: ${SHELL_RC}, ${PROFILE_RC}\n"
SERVERKIT_SUMMARY+="Procesos Node: controlados con confirmación manual.\n"
SERVERKIT_SUMMARY+="-------------------------------------------\n"

# ---------------------------------------------------------------
# Mostrar resumen si se ejecuta directamente
# ---------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo
  echo -e "$SERVERKIT_SUMMARY"
fi