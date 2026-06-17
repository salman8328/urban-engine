#!/usr/bin/env bash
# init-cluster.sh — Bootstrap a 3-node K8s cluster using kubeadm
# Run AFTER: podman-compose up -d (and waiting ~30s for systemd to settle)

set -euo pipefail

MASTER="k8s-master"
WORKER1="k8s-worker1"
WORKER2="k8s-worker2"
POD_CIDR="192.168.0.0/16"   # Calico default — change if using Flannel (10.244.0.0/16)
MASTER_IP="10.89.0.10"

echo "==> Waiting for systemd to be ready in all containers..."
for node in "${MASTER}" "${WORKER1}" "${WORKER2}"; do
    echo -n "    Waiting for ${node}..."
    for i in $(seq 1 30); do
        if podman exec "${node}" systemctl is-system-running --quiet 2>/dev/null; then
            echo " ready."
            break
        fi
        sleep 2
        echo -n "."
    done
done

echo ""
echo "==> Loading kernel modules on all nodes..."
for node in "${MASTER}" "${WORKER1}" "${WORKER2}"; do
    podman exec "${node}" modprobe overlay 2>/dev/null || true
    podman exec "${node}" modprobe br_netfilter 2>/dev/null || true
    podman exec "${node}" sysctl -p /etc/sysctl.d/k8s.conf 2>/dev/null || true
    echo "    ${node}: modules loaded."
done

echo ""
echo "==> Starting containerd on all nodes..."
for node in "${MASTER}" "${WORKER1}" "${WORKER2}"; do
    podman exec "${node}" systemctl start containerd
    echo "    ${node}: containerd started."
done

echo ""
echo "==> Initialising K8s control plane on ${MASTER}..."
podman exec "${MASTER}" kubeadm init \
    --apiserver-advertise-address="${MASTER_IP}" \
    --pod-network-cidr="${POD_CIDR}" \
    --ignore-preflight-errors=all \
    2>&1 | tee /tmp/kubeadm-init.log

echo ""
echo "==> Extracting join command..."
JOIN_CMD=$(grep -A2 "kubeadm join" /tmp/kubeadm-init.log | tr -d '\\\n' | sed 's/kubeadm join/kubeadm join/')
echo "    Join command: ${JOIN_CMD}"

echo ""
echo "==> Setting up kubeconfig on master..."
podman exec "${MASTER}" bash -c "
    mkdir -p /root/.kube && \
    cp /etc/kubernetes/admin.conf /root/.kube/config && \
    chown root:root /root/.kube/config
"

echo ""
echo "==> Installing Calico CNI on master..."
podman exec "${MASTER}" kubectl apply -f \
    https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

echo ""
echo "==> Joining worker nodes..."
for node in "${WORKER1}" "${WORKER2}"; do
    echo "    Joining ${node}..."
    podman exec "${node}" bash -c "${JOIN_CMD} --ignore-preflight-errors=all"
    echo "    ${node}: joined."
done

echo ""
echo "==> Waiting for nodes to become Ready (up to 3 min)..."
for i in $(seq 1 36); do
    READY=$(podman exec "${MASTER}" kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready" || true)
    echo "    Ready nodes: ${READY}/3"
    if [ "${READY}" -eq 3 ]; then
        break
    fi
    sleep 5
done

echo ""
echo "==> Cluster status:"
podman exec "${MASTER}" kubectl get nodes -o wide

echo ""
echo "==> Done! To use kubectl from your host:"
echo "    podman exec -it k8s-master kubectl get nodes"
echo ""
echo "    Or copy kubeconfig to host:"
echo "    podman cp k8s-master:/root/.kube/config ~/.kube/config-k8s-lab"
echo "    export KUBECONFIG=~/.kube/config-k8s-lab"
