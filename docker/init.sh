#!/bin/bash

# MariaDB client 11.4+ enables TLS by default, but the dev MariaDB container
# has no TLS certificates. Disable TLS for the client (local development only).
rm -f /home/frappe/.my.cnf
printf '[client]\nskip-ssl\n' > /home/frappe/.my.cnf

if [ -d "/home/frappe/frappe-bench/apps/frappe" ]; then
    echo "Bench already exists, skipping init"
    cd frappe-bench
    grep -q -- "--host 0.0.0.0" ./Procfile || sed -i '/^web:/s/--port 8000/--host 0.0.0.0 --port 8000/' ./Procfile
    bench start
else
    echo "Creating new bench..."
fi

export PATH="${NVM_DIR}/versions/node/v${NODE_VERSION_DEVELOP}/bin/:${PATH}"

bench init --skip-redis-config-generation frappe-bench

cd frappe-bench

# Bind the dev web server to all interfaces so Docker can publish port 8000.
grep -q -- "--host 0.0.0.0" ./Procfile || sed -i '/^web:/s/--port 8000/--host 0.0.0.0 --port 8000/' ./Procfile

# Use containers instead of localhost
bench set-mariadb-host mariadb
bench set-redis-cache-host redis://redis:6379
bench set-redis-queue-host redis://redis:6379
bench set-redis-socketio-host redis://redis:6379

# Remove redis, watch from Procfile
sed -i '/redis/d' ./Procfile
sed -i '/watch/d' ./Procfile

bench get-app erpnext
bench get-app hrms

bench new-site hrms.localhost \
--force \
--mariadb-root-password 123 \
--admin-password admin \
--no-mariadb-socket

bench --site hrms.localhost install-app hrms
bench --site hrms.localhost set-config developer_mode 1
bench --site hrms.localhost enable-scheduler
bench --site hrms.localhost clear-cache
bench use hrms.localhost

bench start