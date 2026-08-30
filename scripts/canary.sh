#!/usr/bin/env bash
set -euo pipefail

PERCENT="${1:?usage: canary.sh <percent-to-canary 0-100>}"
NGINX_DIR="${NGINX_DIR:-/home/ec2-user/nginx}"
ACTIVE=$(cat "${NGINX_DIR}/ACTIVE_COLOR" 2>/dev/null || echo "blue")

if [ "$ACTIVE" = "blue" ]; then STABLE_PORT=8001; CANARY_PORT=8002; CANARY=green
else                            STABLE_PORT=8002; CANARY_PORT=8001; CANARY=blue; fi

if ! curl -fsS "http://localhost:${CANARY_PORT}/health" > /dev/null; then
  echo "ERROR: canary (${CANARY}) is not healthy - refusing"; exit 1
fi

STABLE_W=$(( (100 - PERCENT) / 10 ))
CANARY_W=$(( PERCENT / 10 ))

echo "==> Sending ${PERCENT}% of traffic to ${CANARY}"

if [ "$CANARY_W" -eq 0 ]; then
  printf 'upstream shipping_active {\n    server 127.0.0.1:%s;\n}\n' "$STABLE_PORT" > "${NGINX_DIR}/conf.d/active.conf"
elif [ "$STABLE_W" -eq 0 ]; then
  printf 'upstream shipping_active {\n    server 127.0.0.1:%s;\n}\n' "$CANARY_PORT" > "${NGINX_DIR}/conf.d/active.conf"
  echo "$CANARY" > "${NGINX_DIR}/ACTIVE_COLOR"
else
  cat > "${NGINX_DIR}/conf.d/active.conf" <<EOF
upstream shipping_active {
    server 127.0.0.1:${STABLE_PORT} weight=${STABLE_W};
    server 127.0.0.1:${CANARY_PORT} weight=${CANARY_W};
}
EOF
fi

docker exec shipping-router nginx -t
docker exec shipping-router nginx -s reload
echo "==> Done"