#!/usr/bin/env bash
set -euo pipefail

NGINX_DIR="${NGINX_DIR:-/home/ec2-user/nginx}"
ACTIVE=$(cat "${NGINX_DIR}/ACTIVE_COLOR" 2>/dev/null || echo "blue")

if [ "$ACTIVE" = "blue" ]; then PREVIOUS="green"; PORT=8002; else PREVIOUS="blue"; PORT=8001; fi

echo "==> Active is ${ACTIVE}; rolling back to ${PREVIOUS}"

if ! docker ps --format '{{.Names}}' | grep -q "^shipping-${PREVIOUS}$"; then
  echo "ERROR: shipping-${PREVIOUS} is not running - nothing to roll back to"
  exit 1
fi

if ! curl -fsS "http://localhost:${PORT}/health" > /dev/null; then
  echo "ERROR: shipping-${PREVIOUS} is not healthy - refusing to roll back into a broken version"
  exit 1
fi

bash "$(dirname "$0")/switch.sh" "${PREVIOUS}"
echo "==> Rollback complete: traffic is on ${PREVIOUS}"