#!/usr/bin/env bash
# setup.sh — Create the Podman network and build the K8s node image
# Run this ONCE before starting the cluster with podman-compose up -d

set -euo pipefail

NETWORK_NAME="k8s-lab"
SUBNET="10.89.0.0/24"
GATEWAY="10.89.0.1"
IMAGE_NAME="k8s-node:almalinux10"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> Checking for existing network: ${NETWORK_NAME}"
if podman network exists "${NETWORK_NAME}" 2>/dev/null; then
    echo "    Network '${NETWORK_NAME}' already exists — skipping creation."
else
    echo "==> Creating Podman network: ${NETWORK_NAME}"
    podman network create \
        --subnet "${SUBNET}" \
        --gateway "${GATEWAY}" \
        --dns-enable=true \
        "${NETWORK_NAME}"
    echo "    Network created."
fi

echo ""
echo "==> Building K8s node image: ${IMAGE_NAME}"
podman build -t "${IMAGE_NAME}" "${COMPOSE_DIR}"
echo "    Image built."

echo ""
echo "==> Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Start the cluster:  cd ${COMPOSE_DIR} && podman-compose up -d"
echo "  2. Wait ~30s for systemd to start inside containers"
echo "  3. Init K8s:           ${SCRIPT_DIR}/init-cluster.sh"
