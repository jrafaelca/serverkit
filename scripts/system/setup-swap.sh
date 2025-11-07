#!/usr/bin/env bash

# ===============================================
# Configuración del archivo swap
# ===============================================
# Crea un archivo de intercambio de 1GB si no existe.
# Aplica parámetros de rendimiento del kernel.
# ===============================================

[[ -z "${SERVERKIT_ENV_INITIALIZED:-}" ]] && source /opt/serverkit/scripts/common/loader.sh

setup_system_swap() {
  log_info "Iniciando configuración del archivo swap..."

  SWAPFILE="/swapfile"
  SIZE="1G"

  # --- Verifica si ya existe swap activo ---
  if swapon --show | grep -q "$SWAPFILE"; then
    log_info "✅ Swap ya existente. No se requiere acción."
    return
  fi

  # --- Intenta crear y activar el archivo swap ---
  log_info "Creando archivo swap de ${SIZE}..."
  if fallocate -l "$SIZE" "$SWAPFILE" 2>/dev/null; then
    chmod 600 "$SWAPFILE"
    mkswap "$SWAPFILE" >/dev/null 2>&1
    if swapon "$SWAPFILE" >/dev/null 2>&1; then
      log_info "Archivo swap creado y activado correctamente."
    else
      log_warn "⚠️ No se pudo activar el swap (posiblemente VM o overlayfs)."
      register_deferred_action "bash /opt/serverkit/scripts/setup-swap.sh"
      return
    fi
  else
    log_error "❌ No se pudo crear el archivo swap (sin soporte fallocate)."
    return 1
  fi

  # --- Persistencia ---
  if ! grep -q "$SWAPFILE" /etc/fstab; then
    echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
  fi

  # --- Ajustes del kernel ---
  {
    echo "vm.swappiness=30"
    echo "vm.vfs_cache_pressure=50"
  } >> /etc/sysctl.conf
  sysctl -p >/dev/null 2>&1 || true

  # --- Validación final ---
  if swapon --show | grep -q "$SWAPFILE"; then
    log_info "✅ Configuración de swap completada correctamente."
  else
    log_error "❌ El archivo swap no quedó activo. Verifica manualmente."
    return 1
  fi
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && setup_system_swap "$@"