#!/usr/bin/env bash
# Usage: scripts/deploy.sh <staging|production>
# Needs: REGISTRY, TAG, BASE_DOMAIN in the environment, and kubectl connected to EKS.
set -euo pipefail

ENV_NAME="$1"
: "${REGISTRY:?REGISTRY is not set}" "${TAG:?TAG is not set}" "${BASE_DOMAIN:?BASE_DOMAIN is not set}"

echo "Deploying ${TAG} to ${ENV_NAME}"

kubectl kustomize "k8s/overlays/${ENV_NAME}" \
  | sed -e "s|__REGISTRY__|${REGISTRY}|g" \
        -e "s|__TAG__|${TAG}|g" \
        -e "s|__DOMAIN__|${BASE_DOMAIN}|g" \
  | kubectl apply -f -

for d in redis api web; do
  kubectl -n "${ENV_NAME}" rollout status "deployment/${d}" --timeout=240s
done

kubectl -n "${ENV_NAME}" get pods -o wide