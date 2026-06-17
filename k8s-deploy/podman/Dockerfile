FROM almalinux:10

# Install systemd and K8s prerequisites
RUN dnf install -y \
    systemd \
    systemd-sysv \
    iproute \
    iptables \
    conntrack-tools \
    socat \
    curl \
    wget \
    ca-certificates \
    gnupg2 \
    procps-ng \
    util-linux \
    hostname \
    && dnf clean all

# Disable unnecessary systemd units that don't work in containers
RUN (cd /lib/systemd/system/sysinit.target.wants/ && \
     for i in *; do [ "$i" = "systemd-tmpfiles-setup.service" ] || rm -f "$i"; done) && \
    rm -f /lib/systemd/system/multi-user.target.wants/* && \
    rm -f /etc/systemd/system/*.wants/* && \
    rm -f /lib/systemd/system/local-fs.target.wants/* && \
    rm -f /lib/systemd/system/sockets.target.wants/*udev* && \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl* && \
    rm -f /lib/systemd/system/basic.target.wants/* && \
    rm -f /lib/systemd/system/anaconda.target.wants/*

# Add Kubernetes repo
RUN cat <<'EOF' > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

# # Install kubeadm, kubelet, kubectl
# RUN dnf install -y --disableexcludes=kubernetes \
#     kubelet \
#     kubeadm \
#     kubectl \
#     && dnf clean all

# # Disable swap (not needed in containers but good practice)
# # Enable kubelet service
# RUN systemctl enable kubelet

# Install containerd as CRI
RUN dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && \
    dnf install -y containerd.io && \
    dnf clean all

# # Configure containerd
# RUN mkdir -p /etc/containerd && \
#     containerd config default > /etc/containerd/config.toml && \
#     sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# RUN systemctl enable containerd

# # Kernel modules and sysctl for K8s networking
# RUN cat <<'EOF' > /etc/modules-load.d/k8s.conf
# overlay
# br_netfilter
# EOF

# RUN cat <<'EOF' > /etc/sysctl.d/k8s.conf
# net.bridge.bridge-nf-call-iptables  = 1
# net.bridge.bridge-nf-call-ip6tables = 1
# net.ipv4.ip_forward                 = 1
# EOF

VOLUME ["/sys/fs/cgroup"]

CMD ["/usr/sbin/init"]
