#!/usr/bin/env bash
# Usage: scripts/smoke-test.sh <staging|production>
# Passes only when the public URL is serving this exact TAG.
set -euo pipefail

ENV_NAME="$1"
: "${TAG:?TAG is not set}" "${BASE_DOMAIN:?BASE_DOMAIN is not set}"

case "${ENV_NAME}" in
  staging)    HOST="staging.${BASE_DOMAIN}" ;;
  production) HOST="app.${BASE_DOMAIN}" ;;
  *) echo "Unknown environment: ${ENV_NAME}"; exit 2 ;;
esac

URL="http://${HOST}/"

for i in $(seq 1 12); do
  BODY="$(curl -fsS --max-time 5 "${URL}" || true)"
  if grep -q "${TAG}" <<<"${BODY}"; then
    echo "Smoke test passed: ${URL} is serving ${TAG}"
    exit 0
  fi
  echo "Waiting for ${URL} to serve ${TAG} (attempt ${i}/12)..."
  sleep 5
done

echo "Smoke test FAILED: ${URL} is not serving ${TAG}"
exit 1