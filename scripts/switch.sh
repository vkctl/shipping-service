#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:?usage: switch.sh <blue|green>}"
NGINX_DIR="${NGINX_DIR:-/home/ec2-user/nginx}"
ACTIVE_FILE="${NGINX_DIR}/conf.d/active.conf"

case "$TARGET" in
  blue)  PORT=8001 ;;
  green) PORT=8002 ;;
  *) echo "ERROR: target must be blue or green"; exit 1 ;;
esac

echo "==> Verifying ${TARGET} is healthy before switching"
if ! curl -fsS "http://localhost:${PORT}/health" > /dev/null; then
  echo "ERROR: ${TARGET} on port ${PORT} is not healthy - refusing to switch"
  exit 1
fi

CURRENT=$(grep -oE '127\.0\.0\.1:[0-9]+' "$ACTIVE_FILE" | head -1 | cut -d: -f2 || echo "unknown")
echo "==> Current upstream port: ${CURRENT} -> switching to ${PORT} (${TARGET})"

cat > "$ACTIVE_FILE" <<EOF
upstream shipping_active {
    server 127.0.0.1:${PORT};
}
EOF

echo "==> Testing nginx config"
docker exec shipping-router nginx -t

echo "==> Reloading nginx (no dropped connections)"
docker exec shipping-router nginx -s reload

sleep 1
echo "==> Verifying through the router"
curl -fsS http://localhost/health
echo
echo "${TARGET}" > "${NGINX_DIR}/ACTIVE_COLOR"
echo "==> Active colour is now ${TARGET}"