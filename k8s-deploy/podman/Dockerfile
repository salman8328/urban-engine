FROM almalinux:10

# Install systemd, sshd, and base tools needed before Ansible takes over
RUN dnf install -y \
    systemd \
    systemd-sysv \
    openssh-server \
    openssh-clients \
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
    python3 \
    sudo \
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

# Generate SSH host keys
RUN ssh-keygen -A

# Enable sshd at boot
RUN systemctl enable sshd

# Allow root SSH login (Ansible needs this)
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Set up root SSH authorized_keys (mount or inject your public key at runtime)
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

# NOTE: containerd, kubeadm, kubelet, kubectl are installed by Ansible (site.yml)
# This image is intentionally minimal — just systemd + sshd base

VOLUME ["/sys/fs/cgroup"]

EXPOSE 22

CMD ["/usr/sbin/init"]
