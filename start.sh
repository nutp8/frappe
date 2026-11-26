#!/usr/bin/env bash
set -euo pipefail

BENCH_DIR="/home/frappe/frappe-bench"
SITES_DIR="${BENCH_DIR}/sites"
SEED_DIR="/home/frappe/sites-seed"
SITE_NAME="${SITE_NAME:-education.local}"
PORT="${PORT:-8000}"

cd "${BENCH_DIR}"

# 1. Sync fresh static assets & apps.txt onto the mounted Persistent Disk
mkdir -p "${SITES_DIR}"
cp -f "${SEED_DIR}/apps.txt" "${SITES_DIR}/apps.txt"
rm -rf "${SITES_DIR}/assets"
cp -a "${SEED_DIR}/assets" "${SITES_DIR}/assets"

# 2. Point Frappe to Render's MariaDB Private Service and Key Value instance
bench set-config -g db_host "${DB_HOST}"
bench set-config -g db_port "${DB_PORT:-3306}"
bench set-config -g redis_cache "${REDIS_URL}"
bench set-config -g redis_queue "${REDIS_URL}"
bench set-config -g redis_socketio "${REDIS_URL}"
bench set-config -g serve_default_site true

# 3. Wait for MariaDB to accept connections
echo "Waiting for MariaDB at ${DB_HOST}:${DB_PORT:-3306}..."
until python3 -c "import socket; s=socket.create_connection(('${DB_HOST}', int('${DB_PORT:-3306}')), 2); s.close()" 2>/dev/null; do
  sleep 2
done

# 4. Create the site only on first boot
if [ ! -d "${SITES_DIR}/${SITE_NAME}" ]; then
  echo "Creating site ${SITE_NAME}..."
  bench new-site "${SITE_NAME}" \
    --no-mariadb-socket \
    --db-host "${DB_HOST}" \
    --db-port "${DB_PORT:-3306}" \
    --mariadb-root-password "${MARIADB_ROOT_PASSWORD}" \
    --admin-password "${ADMIN_PASSWORD}" \
    --install-app erpnext \
    --install-app education
else
  echo "Site ${SITE_NAME} exists; running migrations..."
  bench --site "${SITE_NAME}" migrate
fi

bench use "${SITE_NAME}"

# 5. Start the web server bound to Render's expected port
cd "${SITES_DIR}"
exec "${BENCH_DIR}/env/bin/gunicorn" \
  --bind "0.0.0.0:${PORT}" \
  --workers 2 \
  --threads 4 \
  --timeout 120 \
  --preload \
  frappe.app:application
