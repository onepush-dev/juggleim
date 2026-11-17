#!/bin/bash
# JuggleIM Railway start script (see Dockerfile header).
set -euo pipefail
: "${MYSQL_HOST:?MYSQL_HOST is required}"
: "${MYSQL_PASSWORD:?MYSQL_PASSWORD is required}"
: "${JUGGLEIM_ADMIN_PASSWORD:?JUGGLEIM_ADMIN_PASSWORD is required}"
: "${JUGGLEIM_ADMIN_SECRET:?JUGGLEIM_ADMIN_SECRET is required}"
PUBLIC_DOMAIN="${JUGGLEIM_PUBLIC_DOMAIN:-${RAILWAY_PUBLIC_DOMAIN:-127.0.0.1:8080}}"
export MYSQL_PWD="$MYSQL_PASSWORD"
M=(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" --protocol=TCP)

echo "railway: waiting for MySQL at $MYSQL_HOST:$MYSQL_PORT"
for i in $(seq 1 90); do
  if "${M[@]}" -e "SELECT 1" >/dev/null 2>&1; then break; fi
  sleep 2
  [ "$i" = 90 ] && { echo "railway: MySQL not reachable"; exit 1; }
done

"${M[@]}" -e "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci"
if [ "$("${M[@]}" -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$MYSQL_DB_NAME' AND table_name='globalconfs'")" = "0" ]; then
  echo "railway: first boot, creating the JuggleIM schema"
  "${M[@]}" "$MYSQL_DB_NAME" < /opt/sql/imserver.sql
fi
MQ=("${M[@]}" "$MYSQL_DB_NAME")
# Replace the upstream default admin password (sha1 of 123456) with the generated one. Leaves it alone once changed.
ADMIN_SHA1=$(printf '%s' "$JUGGLEIM_ADMIN_PASSWORD" | sha1sum | cut -d' ' -f1)
"${MQ[@]}" -e "INSERT IGNORE INTO accounts(account,password) VALUES('$JUGGLEIM_ADMIN_USER','$ADMIN_SHA1'); UPDATE accounts SET password='$ADMIN_SHA1' WHERE account='$JUGGLEIM_ADMIN_USER' AND password='7c4a8d09ca3762af61e59520943dc26494f8941b';"
# Address the navigator hands to client SDKs (WSS through Railway's HTTPS edge on 443).
"${MQ[@]}" -e "INSERT INTO globalconfs(conf_key,conf_value) VALUES('connect_address','{\"default\":[\"$PUBLIC_DOMAIN\"]}') ON DUPLICATE KEY UPDATE conf_value=VALUES(conf_value);"

cat > /opt/conf/config.yml <<CFG
nodeName: ${POD_NAME:-jim-node-1}
nodeHost: 127.0.0.1
msgStoreEngine: mysql
adminSecret: ${JUGGLEIM_ADMIN_SECRET}

log:
  logPath: ./logs
  logName: jim-info

kvdb:
  isOpen: true

mysql:
  user: ${MYSQL_USER}
  password: ${MYSQL_PASSWORD}
  address: ${MYSQL_HOST}:${MYSQL_PORT}
  name: ${MYSQL_DB_NAME}

connectManager:
  wsPort: 9003

apiGateway:
  httpPort: 9001

navGateway:
  httpPort: 9002

adminGateway:
  httpPort: 8090

imApiDomain: http://127.0.0.1:9001
CFG

caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &
echo "railway: JuggleIM starting; admin console https://$PUBLIC_DOMAIN (user $JUGGLEIM_ADMIN_USER, password = JUGGLEIM_ADMIN_PASSWORD in Variables)"
exec /opt/imserver
