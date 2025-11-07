#!/usr/bin/env bash

# ===============================================
# Instalación y configuración de PgBouncer
# ===============================================
# Instala PgBouncer, crea usuario administrativo,
# habilita TLS (TLSv1–TLSv1.3) y aplica parámetros
# de conexión recomendados con hardening de servicio.
# ===============================================

[[ -z "${SERVERKIT_ENV_INITIALIZED:-}" ]] && source /opt/serverkit/scripts/common/loader.sh

install_pgbouncer() {
  log_info "Instalando y configurando PgBouncer..."

  # --- Paquetes ---
  apt-get update -y >> "$LOG_FILE" 2>&1
  apt-get install -y pgbouncer postgresql-client openssl >> "$LOG_FILE" 2>&1

  # --- Usuario y directorios ---
  id pgbouncer &>/dev/null || useradd -r -s /usr/sbin/nologin -d /var/run/pgbouncer pgbouncer
  install -d -o pgbouncer -g pgbouncer -m 0750 /etc/pgbouncer
  install -d -o pgbouncer -g pgbouncer -m 0750 /var/log/pgbouncer

  INI="/etc/pgbouncer/pgbouncer.ini"
  USERLIST="/etc/pgbouncer/userlist.txt"
  CRT="/etc/pgbouncer/server.crt"
  KEY="/etc/pgbouncer/server.key"

  # --- Usuario administrativo ---
  PGADMIN_USER="pgbouncer"
  PGADMIN_PASS="$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-18)"
  MD5_HASH="md5$(printf '%s' "${PGADMIN_PASS}${PGADMIN_USER}" | md5sum | awk '{print $1}')"

  echo "\"${PGADMIN_USER}\" \"${MD5_HASH}\"" > "$USERLIST"
  chown pgbouncer:pgbouncer "$USERLIST"
  chmod 600 "$USERLIST"

  # --- Certificados TLS ---
 if [[ ! -f "$CRT" || ! -f "$KEY" ]]; then
   openssl req -x509 -nodes -newkey rsa:2048 \
     -keyout "$KEY" -out "$CRT" -days 3650 \
     -subj "/CN=$(hostname -f)" >> "$LOG_FILE" 2>&1
   chown pgbouncer:pgbouncer "$CRT" "$KEY"
   chmod 640 "$CRT" "$KEY"
 fi

  # --- Configuración principal ---
  cat > "$INI" <<'EOF'
[databases]
;db = host=localhost port=5432 dbname=postgres user=postgres

[pgbouncer]
listen_addr             = $(hostname -I | awk '{print $1}')
listen_port             = 6432
unix_socket_dir         = /tmp

pool_mode               = transaction
max_client_conn         = 500
default_pool_size       = 40
min_pool_size           = 5
reserve_pool_size       = 10
reserve_pool_timeout    = 5
server_idle_timeout     = 30
query_timeout           = 120
server_connect_timeout  = 5
server_login_retry      = 5

logfile                 = /var/log/pgbouncer/pgbouncer.log
pidfile                 = /var/run/pgbouncer/pgbouncer.pid
stats_period            = 60

auth_type               = md5
auth_file               = /etc/pgbouncer/userlist.txt
admin_users             = ${PGADMIN_USER}
stats_users             = ${PGADMIN_USER}

client_tls_sslmode      = require
client_tls_key_file     = /etc/pgbouncer/server.key
client_tls_cert_file    = /etc/pgbouncer/server.crt
client_tls_protocols    = all

server_tls_sslmode      = require
server_check_query      = select 1

tcp_keepalive           = 1
tcp_keepcnt             = 5
tcp_keepidle            = 30
tcp_keepintvl           = 10

client_idle_timeout     = 300
query_wait_timeout      = 120
cancel_wait_timeout     = 10

ignore_startup_parameters = extra_float_digits
EOF

  chown pgbouncer:pgbouncer "$INI"
  chmod 640 "$INI"

  # --- Hardening del servicio ---
  install -d /etc/systemd/system/pgbouncer.service.d
  cat > /etc/systemd/system/pgbouncer.service.d/override.conf <<'EOF'
[Service]
User=pgbouncer
Group=pgbouncer
UMask=007
RuntimeDirectory=pgbouncer
RuntimeDirectoryMode=0750
ProtectSystem=full
ProtectHome=true
PrivateTmp=true
NoNewPrivileges=true
CapabilityBoundingSet=
RestrictSUIDSGID=yes
RestrictRealtime=yes
EOF

  # --- Logrotate ---
  cat > /etc/logrotate.d/pgbouncer <<'EOF'
/var/log/pgbouncer/pgbouncer.log {
    daily
    rotate 7
    missingok
    notifempty
    compress
    delaycompress
    maxsize 100M
    copytruncate
    postrotate
        /bin/systemctl reload pgbouncer >/dev/null 2>&1 || true
    endscript
}
EOF

  # --- Arranque y validación ---
  systemctl daemon-reexec >/dev/null 2>&1 || true
  systemctl daemon-reload >/dev/null 2>&1 || true
  systemctl enable --now pgbouncer >/dev/null 2>&1 || true
  systemctl reload pgbouncer >/dev/null 2>&1 || true

  sleep 2

  if ! systemctl is-active --quiet pgbouncer; then
    log_error "PgBouncer no inició correctamente."
    return 1
  fi

  echo
  echo "PgBouncer instalado correctamente."

  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "==============================================="
    echo "Admin user : ${PGADMIN_USER}"
    echo "Admin pass : ${PGADMIN_PASS}"
    echo "Puerto     : 6432"
    echo "TLS        : habilitado (TLSv1–TLSv1.3)"
    echo "Modo pool  : transaction"
    echo
    echo "Para limpiar del historial los datos sensibles, ejecuta (una sola línea):"
    echo "  history -c && history -w && rm -f ~/.bash_history"
    echo "==========================================="
  fi
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && install_pgbouncer "$@"