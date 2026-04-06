#!/bin/bash

NODENAME=$1
REPONAME=Kubecon26-example-repo

function os_update() {
  apt update 
  apt upgrade -y
}

function install_aws_cli() {
  export HOME="/root"

  cd /tmp
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  ./aws/install
}

function install_k9s() {
  export HOME="/root"

  curl -sS https://webinstall.dev/k9s | bash
  cp ~/.local/bin/k9s /usr/local/bin
}

function install_helm() {
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
  chmod 700 get_helm.sh
  ./get_helm.sh
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
  mv /clone/$REPONAME/aws-deployment/install/id_rsa-$NODENAME /home/kubernetes/.ssh/id_rsa
  chmod 400 /home/kubernetes/.ssh/id_rsa
  mv /clone/$REPONAME/aws-deployment/install/id_rsa-$NODENAME.pub /home/kubernetes/.ssh/id_rsa.pub
  chmod 400 /home/kubernetes/.ssh/id_rsa.pub
  mv /clone/$REPONAME/aws-deployment/install/authorized_keys-$NODENAME /home/kubernetes/.ssh/authorized_keys
  chmod 400 /home/kubernetes/.ssh/authorized_keys

  systemctl daemon-reload
  systemctl restart ssh
}

function install_kubernetes_control() {
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

  kubeadm init
  kubeadm token create --print-join-command > /home/kubernetes/join-cmd.sh
}

function make_it_possible_for_a_user_to_use_kubectl() {
  USER=$1

  mkdir -p /home/$USER/.kube
  cp /etc/kubernetes/admin.conf /home/$USER/.kube/config
  chown $(id -u $USER):$(id -g $USER) /home/$USER/.kube/config
}

function make_it_possible_to_use_kubectl() {
  make_it_possible_for_a_user_to_use_kubectl kubernetes
  export KUBECONFIG=/etc/kubernetes/admin.conf
}

function change_permissions() {
  chown kubernetes:kubernetes -R /home/kubernetes
  chown kubernetes:kubernetes -R /opt
  chown kubernetes:kubernetes -R /clone
}

function install_cilium() {
  CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
  CLI_ARCH=amd64
  if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
  curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/$CILIUM_CLI_VERSION/cilium-linux-$CLI_ARCH.tar.gz{,.sha256sum}
  sha256sum --check cilium-linux-$CLI_ARCH.tar.gz.sha256sum
  sudo tar xzvfC cilium-linux-$CLI_ARCH.tar.gz /usr/local/bin
  rm cilium-linux-$CLI_ARCH.tar.gz{,.sha256sum}

  cilium install --set securityContext.privileged=true
}

function install_kgateway() {
  helm install kgateway-crds oci://cr.kgateway.dev/kgateway-dev/charts/kgateway-crds --version v2.2.2 --namespace kgateway-system --create-namespace
  helm install kgateway oci://cr.kgateway.dev/kgateway-dev/charts/kgateway --version v2.2.2 --namespace kgateway-system --create-namespace
  kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml
}

function install_argocd() {                  
  cd /tmp
  kubectl create namespace argocd
  kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  
  curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
  rm argocd-linux-amd64
  allow_external_access argocd argocd-server 30007
}

function install_external_secrets_operator() {
  helm repo add external-secrets https://charts.external-secrets.io

  helm install external-secrets \
      external-secrets/external-secrets \
      -n external-secrets \
      --create-namespace
}

function install_examples() {
  cd /clone/$REPONAME/examples
  EXAMPLES=$(ls)
  for EXAMPLE in $EXAMPLES
  do
      bash $EXAMPLE/install/install.sh
  done  
}

function allow_external_access() {
  NAMESPACE=$1
  SERVICE=$2
  EXTERNAL_PORT=$3

  kubectl patch svc "$SERVICE" -n "$NAMESPACE" -p '{"spec": {"type": "NodePort"}}'
  kubectl patch svc "$SERVICE" -n "$NAMESPACE" --type json -p "[{\"op\": \"add\", \"path\": \"/spec/ports/0/nodePort\", \"value\":$EXTERNAL_PORT}]"
}

function force_password_change() {
  passwd -e kubernetes
}

os_update
install_aws_cli
install_k9s
install_helm

change_hostname $NODENAME
add_hostnames_to_hosts_file
sudu_no_passwd

add_user kubernetes
use_vim kubernetes
use_vim root

create_ssh_keyfiles
change_permissions

install_kubernetes_control
make_it_possible_to_use_kubectl
change_permissions
echo wait 30 seconds
sleep 30
install_cilium
install_kgateway
install_argocd
install_external_secrets_operator
echo "$(date +%H:%M:%S) Wait for 3 minutes..."
sleep 180
install_examples

echo $(date +%H:%M:%S) wait 3 minutes
sleep 180
force_password_change
