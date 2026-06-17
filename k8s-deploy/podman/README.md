# K8s Lab — 3-node cluster via Podman + systemd AlmaLinux 9

A local 3-node Kubernetes cluster running inside Podman containers on a single machine.
Each container runs AlmaLinux 9 with systemd, containerd, kubeadm, kubelet, and kubectl.

## Architecture

```
Host (AlmaLinux)
└── Podman network: k8s-lab (10.89.0.0/24)
    ├── k8s-master   10.89.0.10  — control plane (API server, etcd, scheduler)
    ├── k8s-worker1  10.89.0.11  — worker node
    └── k8s-worker2  10.89.0.12  — worker node
```

## Prerequisites

```bash
# Install podman-compose
sudo dnf install -y podman-compose

# Or via pip
pip3 install podman-compose
```

## Quick Start

### Step 1 — Build image & create network
```bash
cd k8s-deploy/podman
sudo bash scripts/setup.sh
```

### Step 2 — Start the 3 containers
```bash
sudo podman-compose up -d
```

### Step 3 — Wait ~30s, then bootstrap K8s
```bash
sudo bash scripts/init-cluster.sh
```

### Step 4 — Use kubectl
```bash
# From inside master container
sudo podman exec -it k8s-master kubectl get nodes

# Or copy kubeconfig to host
sudo podman cp k8s-master:/root/.kube/config ~/.kube/config-k8s-lab
export KUBECONFIG=~/.kube/config-k8s-lab
kubectl get nodes
```

## Expected output after init

```
NAME          STATUS   ROLES           AGE   VERSION
k8s-master    Ready    control-plane   2m    v1.29.x
k8s-worker1   Ready    <none>          1m    v1.29.x
k8s-worker2   Ready    <none>          1m    v1.29.x
```

## Teardown

```bash
# Stop and remove containers
sudo podman-compose down

# Remove volumes too
sudo podman-compose down -v

# Remove the network
sudo podman network rm k8s-lab

# Remove the image
sudo podman rmi k8s-node:almalinux9
```

## Troubleshooting

### Containers not starting
```bash
sudo podman logs k8s-master
sudo podman exec k8s-master systemctl status
```

### kubeadm init fails
```bash
# Check preflight errors
sudo podman exec k8s-master kubeadm init --dry-run --ignore-preflight-errors=all

# Check containerd
sudo podman exec k8s-master systemctl status containerd
```

### Nodes not joining
```bash
# Re-generate join token on master
sudo podman exec k8s-master kubeadm token create --print-join-command
```

### CNI / networking issues
```bash
# Check Calico pods
sudo podman exec k8s-master kubectl get pods -n kube-system

# Check node conditions
sudo podman exec k8s-master kubectl describe node k8s-worker1
```

## Files

```
podman/
├── Dockerfile              # AlmaLinux 9 + systemd + kubeadm + containerd
├── docker-compose.yml      # 3-node cluster definition
├── network.yaml            # Network reference config
├── README.md               # This file
└── scripts/
    ├── setup.sh            # Create network + build image (run once)
    └── init-cluster.sh     # Bootstrap K8s with kubeadm
```
