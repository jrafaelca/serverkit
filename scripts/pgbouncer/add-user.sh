#!/usr/bin/env bash
set -euo pipefail

USERLIST="/etc/pgbouncer/userlist.txt"

if [[ $# -lt 1 ]]; then
  echo "Uso: $0 <usuario> [password]"
  exit 1
fi

NEW_USER="$1"
NEW_PASS="${2:-}"

# Generar contraseña si no viene
if [[ -z "$NEW_PASS" ]]; then
  NEW_PASS="$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-18)"
fi

# Validar archivo
if [[ ! -f "$USERLIST" ]]; then
  echo "Error: No existe $USERLIST"
  exit 1
fi

# Si el usuario ya existe → no hacemos nada
if grep -q "\"${NEW_USER}\"" "$USERLIST"; then
  echo
  echo "==========================================="
  echo "El usuario '${NEW_USER}' ya existe. No se realizaron cambios."
  echo "==========================================="
  exit 0
fi

# Generar hash MD5 estilo PostgreSQL
MD5_HASH="md5$(printf '%s' "${NEW_PASS}${NEW_USER}" | md5sum | awk '{print $1}')"

# Agregar usuario nuevo
echo "\"${NEW_USER}\" \"${MD5_HASH}\"" >> "$USERLIST"

# Resumen final
echo
echo "==========================================="
echo "Usuario PgBouncer creado correctamente"
echo "==========================================="
echo "Usuario:     ${NEW_USER}"
echo "Contraseña:  ${NEW_PASS}"
echo "Archivo:     ${USERLIST}"
echo "==========================================="
echo