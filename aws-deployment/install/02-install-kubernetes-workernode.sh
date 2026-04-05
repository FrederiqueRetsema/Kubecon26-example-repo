#!/bin/bash
NODENAME=$1

function os_update() {
  apt update 
  apt upgrade -y
}

function change_hostname() {
  hostname=$1
  echo $hostname > /etc/hostname
  hostname $hostname
}

function add_hostnames_to_hosts_file() {
  echo "172.31.0.10 control" >> /etc/hosts
  echo "172.31.0.11 worker" >> /etc/hosts
  echo "172.31.0.12 worker2" >> /etc/hosts
}

function sudu_no_passwd() {
  groupadd admin
  sed -i "s/%admin ALL=(ALL) ALL/%admin ALL=(ALL) NOPASSWD: ALL/" /etc/sudoers 
}

function add_user() {
  USERNAME=$1

  echo /usr/sbin/useradd -d /home/$USERNAME -G admin -m -s /bin/bash $USERNAME > /var/log/useradd.txt
  /usr/sbin/useradd -d /home/$USERNAME -G admin -m -s /bin/bash $USERNAME 
  echo -e "##DefaultPassword##\n##DefaultPassword##" | passwd $USERNAME
}

function use_vim() {
  USERNAME=$1

  echo "export VISUAL=vim" >> /home/$USERNAME/.bashrc
}

function create_ssh_keyfiles() {
  mkdir -p /home/kubernetes/.ssh
  mv /clone/Kubecon26-example-repo/aws-deployment/install/id_rsa-$NODENAME /home/kubernetes/.ssh/id_rsa
  chmod 400 /home/kubernetes/.ssh/id_rsa
  mv /clone/Kubecon26-example-repo/aws-deployment/install/id_rsa-$NODENAME.pub /home/kubernetes/.ssh/id_rsa.pub
  chmod 400 /home/kubernetes/.ssh/id_rsa.pub
  mv /clone/Kubecon26-example-repo/aws-deployment/install/authorized_keys-$NODENAME /home/kubernetes/.ssh/authorized_keys
  chmod 400 /home/kubernetes/.ssh/authorized_keys

  systemctl daemon-reload
  systemctl restart ssh
}

function install_kubernetes_worker() {
  mkdir -p /opt/kubernetes
  cd /opt/kubernetes

  apt update && apt upgrade -y
  apt install openssh-server -y
  systemctl enable --now ssh
  ufw allow ssh
  ufw reload
  sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

  LINE_NO=$(grep -n swap /etc/fstab | awk -F':' '{print $1}')
  sed -i "$LINE_NO""d" /etc/fstab 
  swapoff -a

  echo "overlay" > /etc/modules-load.d/k8s.conf
  echo "br_netfilter" >> /etc/modules-load.d/k8s.conf
  modprobe overlay
  modprobe br_netfilter

  echo "net.bridge.bridge-nf-call-iptables  = 1" > /etc/sysctl.d/k8s.conf
  echo "net.bridge.bridge-nf-call-ip6tables = 1" >> /etc/sysctl.d/k8s.conf
  echo "net.ipv4.ip_forward                 = 1" >> /etc/sysctl.d/k8s.conf

  sysctl --system

  mkdir -p /usr/local/lib/systemd/system
  cd /tmp
  curl -OL https://github.com/containerd/containerd/releases/download/v2.2.2/containerd-2.2.2-linux-amd64.tar.gz
  tar Cxzvf /usr/local containerd-2.2.2-linux-amd64.tar.gz

  curl -OL https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
  cp containerd.service /usr/local/lib/systemd/system/containerd.service

  curl -OL https://github.com/opencontainers/runc/releases/download/v1.3.5/runc.amd64
  install -m 755 runc.amd64 /usr/local/sbin/runc

  curl -OL https://github.com/containernetworking/plugins/releases/download/v1.9.1/cni-plugins-linux-amd64-v1.9.1.tgz
  mkdir -p /opt/cni/bin
  tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.9.1.tgz

  systemctl daemon-reload
  systemctl enable --now containerd

  mkdir -p /etc/containerd
  containerd config default | tee /etc/containerd/config.toml

  apt-get install -y apt-transport-https ca-certificates curl gpg
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"

  # Link: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
  mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

  echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
  apt update
  apt-get install -y kubelet kubeadm kubectl
  apt-mark hold kubelet kubeadm kubectl

  systemctl enable --now kubelet
}

function join_cluster() {
  su - kubernetes
  cd ~kubernetes

  while true
  do
    sudo -u kubernetes scp -o StrictHostKeyChecking=no kubernetes@control:/home/kubernetes/join-cmd.sh .

    if test -f ./join-cmd.sh
    then
      sudo bash ./join-cmd.sh
      break
    else
      echo wait for join command...
      sleep 10
    fi
  done
}

function change_permissions() {
  chown kubernetes:kubernetes -R /home/kubernetes
  chown kubernetes:kubernetes -R /opt
  chown kubernetes:kubernetes -R /clone
}

function force_password_change() {
  passwd -e kubernetes
}

os_update
change_hostname $NODENAME
add_hostnames_to_hosts_file
sudu_no_passwd

add_user kubernetes
use_vim kubernetes
use_vim root

create_ssh_keyfiles
change_permissions

install_kubernetes_worker
change_permissions

join_cluster

sleep 300
force_password_change
