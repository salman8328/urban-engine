# K8s Lab — 3-node cluster via Podman + Ansible + AlmaLinux 10

A local 3-node Kubernetes cluster running inside Podman containers on a single machine.
Each container runs AlmaLinux 10 with systemd + sshd. All K8s software is installed and
configured via Ansible (mirroring the foreman repo structure).

## Architecture

```
Host (AlmaLinux)
└── Podman network: k8s-lab (10.89.0.0/24)
    ├── k8s-master   10.89.0.10  — control plane  (SSH → host:2210)
    ├── k8s-worker1  10.89.0.11  — worker node    (SSH → host:2211)
    └── k8s-worker2  10.89.0.12  — worker node    (SSH → host:2212)
```

**DNS**: Podman's `netavark` + `aardvark-dns` backend resolves container hostnames
within the `k8s-lab` network automatically (e.g. `k8s-master`, `k8s-worker1`).

**SSH**: Each container maps port 22 to a unique host port so Ansible can reach them
via `127.0.0.1:2210/2211/2212`.

## Directory layout

```
k8s-deploy/
├── podman/
│   ├── Dockerfile              # AlmaLinux 10 + systemd + sshd (minimal base)
│   ├── docker-compose.yml      # 3-node cluster definition
│   ├── network.yaml            # Network reference config
│   ├── README.md               # This file
│   └── scripts/
│       └── setup.sh            # Create network + build image (run once)
└── ansible/
    ├── ansible.cfg             # Ansible config (inventory, roles_path, ssh args)
    ├── inventory/
    │   └── lab/
    │       ├── lab.yml         # Hosts + SSH ports + node IPs
    │       └── group_vars/
    │           └── k8s_lab/
    │               └── main.yml  # K8s version, pod CIDR, sshd vars
    └── playbooks/
        ├── site.yml            # Install containerd + kubeadm on all nodes
        ├── k8s-init.yml        # Bootstrap cluster (replaces init-cluster.sh)
        └── roles/
            ├── common/         # kernel modules, sysctl, sshd
            ├── containerd/     # install + configure + start containerd
            ├── kubeadm/        # install kubelet/kubeadm/kubectl + enable kubelet
            ├── k8s_control_plane/  # kubeadm init, kubeconfig, Calico CNI, join token
            └── k8s_worker/     # kubeadm join
```

## Prerequisites

```bash
# On the AlmaLinux host:
sudo dnf install -y podman-compose ansible python3-pip
pip3 install ansible

# Install required Ansible collections
ansible-galaxy collection install community.general ansible.posix
```

## Quick Start

### Step 1 — Build image & create network (once)
```bash
cd k8s-deploy/podman
sudo bash scripts/setup.sh
```

### Step 2 — Start the 3 containers
```bash
sudo podman-compose up -d

# Wait ~15s for systemd to settle, then verify SSH works:
ssh -p 2210 -o StrictHostKeyChecking=no root@127.0.0.1 hostname
```

### Step 3 — Install K8s prerequisites on all nodes
```bash
cd ../ansible
ansible-playbook playbooks/site.yml
```

### Step 4 — Bootstrap the K8s cluster
```bash
ansible-playbook playbooks/k8s-init.yml
```

### Step 5 — Use kubectl
```bash
# From inside master container
sudo podman exec -it k8s-master kubectl get nodes -o wide

# Or copy kubeconfig to host
sudo podman cp k8s-master:/root/.kube/config ~/.kube/config-k8s-lab
export KUBECONFIG=~/.kube/config-k8s-lab
kubectl get nodes
```

## Expected output

```
NAME          STATUS   ROLES           AGE   VERSION
k8s-master    Ready    control-plane   2m    v1.29.x
k8s-worker1   Ready    <none>          1m    v1.29.x
k8s-worker2   Ready    <none>          1m    v1.29.x
```

## Teardown

```bash
cd podman
sudo podman-compose down -v
sudo podman network rm k8s-lab
sudo podman rmi k8s-node:almalinux10
```

## Troubleshooting

### SSH not working
```bash
# Check sshd is running inside container
sudo podman exec k8s-master systemctl status sshd

# Check your public key is mounted
sudo podman exec k8s-master cat /root/.ssh/authorized_keys
```

### Ansible can't connect
```bash
cd ansible
ansible all -m ping
```

### kubeadm init fails
```bash
sudo podman exec k8s-master kubeadm init --dry-run --ignore-preflight-errors=all
sudo podman exec k8s-master systemctl status containerd
```

### Re-run only a specific role
```bash
ansible-playbook playbooks/site.yml --tags containerd
```

### Nodes not joining — regenerate token
```bash
sudo podman exec k8s-master kubeadm token create --print-join-command
```
