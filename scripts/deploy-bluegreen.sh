#!/usr/bin/env bash
set -euo pipefail

: "${IMAGE:?IMAGE is required}"
APP_ENVIRONMENT="${APP_ENVIRONMENT:-production}"
NGINX_DIR="${NGINX_DIR:-/home/ec2-user/nginx}"

if [ -f "${NGINX_DIR}/ACTIVE_COLOR" ]; then
  ACTIVE=$(cat "${NGINX_DIR}/ACTIVE_COLOR")
else
  ACTIVE="blue"
fi

if [ "$ACTIVE" = "blue" ]; then
  IDLE="green"; IDLE_PORT=8002
else
  IDLE="blue";  IDLE_PORT=8001
fi

echo "==> Active: ${ACTIVE}. Deploying ${IMAGE} to idle slot: ${IDLE} (port ${IDLE_PORT})"

docker pull "$IMAGE"
docker rm -f "shipping-${IDLE}" 2>/dev/null || true
docker run -d \
  --name "shipping-${IDLE}" \
  --restart unless-stopped \
  -p "127.0.0.1:${IDLE_PORT}:8000" \
  -e APP_ENVIRONMENT="${APP_ENVIRONMENT}" \
  -e APP_COLOR="${IDLE}" \
  "$IMAGE"

echo "==> Waiting for ${IDLE} to become healthy (traffic still on ${ACTIVE})"
for i in $(seq 1 30); do
  if curl -fsS "http://localhost:${IDLE_PORT}/health" > /dev/null 2>&1; then
    echo "==> ${IDLE} healthy after ${i}s"
    curl -sS "http://localhost:${IDLE_PORT}/health"; echo
    break
  fi
  if [ "$i" = "30" ]; then
    echo "ERROR: ${IDLE} never became healthy. Traffic untouched on ${ACTIVE}."
    docker logs --tail 50 "shipping-${IDLE}" || true
    docker rm -f "shipping-${IDLE}" || true
    exit 1
  fi
  sleep 1
done

echo "==> Smoke testing ${IDLE} directly"
curl -fsS -X POST "http://localhost:${IDLE_PORT}/quote" \
  -H 'Content-Type: application/json' \
  -d '{"weight_kg": 10, "tier": "express"}' | grep -q '"cost":150.0'
echo "==> Smoke test passed"

echo "==> Switching traffic to ${IDLE}"
bash "$(dirname "$0")/switch.sh" "${IDLE}"

echo "==> Deployment complete. ${ACTIVE} is now idle and kept for instant rollback."