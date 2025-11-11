#!/usr/bin/env bash

# Evitar inicialización múltiple
[[ -n "${SERVERKIT_INITIALIZED:-}" ]] && return
export SERVERKIT_INITIALIZED=true

# Bloquear ejecución directa
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && {
  echo "No se puede ejecutar este archivo directamente."
  exit 1
}

# Requiere permisos de root
(( EUID != 0 )) && {
  echo "Se necesitan permisos de root (usa sudo)." >&2
  exit 1
}

# Validar sistema operativo
source /etc/os-release || true
SUPPORTED_VERSIONS=("22.04" "24.04")

if [[ "$NAME" != "Ubuntu" || ! " ${SUPPORTED_VERSIONS[*]} " =~ ${VERSION_ID} ]]; then
  echo "Sistema operativo no soportado: $PRETTY_NAME" >&2
  exit 1
fi

# Inicializar resumen global si no existe
if [[ -z "${SERVERKIT_SUMMARY+x}" ]]; then
  export SERVERKIT_SUMMARY=""
fi