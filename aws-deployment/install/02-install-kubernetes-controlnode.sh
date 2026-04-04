#!/bin/bash

function os_update() {
  apt update 
  apt upgrade -y
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
  echo -e "${DefaultPassword}\n${DefaultPassword}" | passwd $USERNAME
}

function use_vim() {
  USERNAME=$1

  echo "export VISUAL=vim" >> /home/$USERNAME/.bashrc
}

function copy_examples() {
  USERNAME=$1

  mkdir -p /home/$USERNAME/examples
  cp /opt/xforce/examples/* /home/$USERNAME/examples
  chown -R $USERNAME:$USERNAME /home/$USERNAME/examples
}

function create_ssh_keyfiles() {
  mkdir -p /home/kubernetes/.ssh
  mv /clone/Kubecon26-example-repo/aws-deployment/install/id_rsa /home/kubernetes/.ssh/id_rsa
  chmod 400 /home/kubernetes/.ssh/id_rsa
  mv /clone/Kubecon26-example-repo/aws-deployment/install/id_rsa.pub /home/kubernetes/.ssh/id_rsa.pub
  chmod 400 /home/kubernetes/.ssh/id_rsa.pub
  mv /clone/Kubecon26-example-repo/aws-deployment/install/authorized_keys /home/kubernetes/.ssh/authorized_keys
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
}

function argocd_wait_for_healty() {
  APP=$1

  argocd app list | tee /tmp/$
  if [[ ! -z "$(cat /tmp/$ | grep "$APP" | awk '{print $5}' | grep OutOfSync)" ]]
  then
    echo "Sync $APP"
    argocd app sync $APP >/dev/null 2>&1
  fi

  while true
  do
      argocd app list | tee /tmp/$
      if [[ ! -z "$(cat /tmp/$ | grep "$APP" | awk '{print $6}' | grep Healthy)" ]]
      then
        break
      fi
      echo "Wait another 10 seconds"
      sleep 10
  done
}

function install_external_secrets_gitops_example() {
  cd /opt/xforce/examples
  export HOME="/root"
  git clone https://github.com/FrederiqueRetsema/external-secrets-gitops-example.git

  ARGOCD_PWD=$(argocd admin initial-password -n argocd | head -n 1)
  ARGOCD_IP=$(kubectl get svc -n argocd argocd-server | tail -n 1 | awk '{print $3}')
  echo "Pwd admin = $ARGOCD_PWD"

  argocd login $ARGOCD_IP:80 --username admin --password $ARGOCD_PWD --insecure
  argocd app create vault \
  --project default \
  --repo https://helm.releases.hashicorp.com \
  --helm-chart vault \
  --revision 0.28.0 \
  --sync-policy auto \
  --sync-option CreateNamespace=true \
  --parameter server.dev.enabled=true \
  --dest-namespace vault \
  --dest-server https://kubernetes.default.svc

  argocd_wait_for_healty vault

  kubectl exec -i vault-0 -n vault -- /bin/sh <<EOF
vault login root
EOF
  sleep 2
  kubectl exec -i vault-0 -n vault -- /bin/sh <<EOF

# Write the demo credentials
vault kv put secret/mysql_credentials \
  url="mysql.example.com:3306" \
  username="my_demo_user" \
  password="my_demo_password"
EOF
  sleep 2
  kubectl exec -i vault-0 -n vault -- /bin/sh <<EOF

# Enable Kubernetes auth
vault auth enable kubernetes
vault write auth/kubernetes/config \
  kubernetes_host="https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT"
EOF

  kubectl exec -i vault-0 -n vault -- /bin/sh <<EOF

# Policy and role for ESO
vault policy write eso-read-policy - <<EOF2
path "secret/*" {
  capabilities = [ "read", "list" ]
}
EOF2
EOF
  sleep 2
  kubectl exec -i vault-0 -n vault -- /bin/sh <<EOF
vault write auth/kubernetes/role/demo \
  bound_service_account_names=* \
  bound_service_account_namespaces=* \
  policies=eso-read-policy \
  ttl=24h

exit
EOF

  sleep 10

  argocd app create eso \
  --project default \
  --repo https://charts.external-secrets.io \
  --helm-chart external-secrets \
  --revision 0.9.19 \
  --sync-policy auto \
  --sync-option CreateNamespace=true \
  --dest-namespace external-secrets \
  --dest-server https://kubernetes.default.svc

  argocd_wait_for_healty eso

  argocd app create vault-secret-store \
  --project default \
  --repo https://github.com/FrederiqueRetsema/external-secrets-gitops-example.git \
  --path "./manifests/vault-integration" \
  --sync-policy auto \
  --dest-namespace external-secrets \
  --dest-server https://kubernetes.default.svc

  argocd_wait_for_healty vault-secret-store
  sleep 5

  echo "Should show READY: True"
  kubectl get clustersecretstore vault-backend  # should show READY: True
  
  argocd app create my-secret-app \
  --project default \
  --repo https://github.com/FrederiqueRetsema/external-secrets-gitops-example.git \
  --path "./manifests/app" \
  --sync-policy auto \
  --dest-namespace default \
  --dest-server https://kubernetes.default.svc                  
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
install_k9s
install_helm

change_hostname control
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

echo $(date +%H:%M:%S) wait 3 minutes
sleep 180
install_external_secrets_gitops_example
allow_external_access argocd argocd-server 30007
allow_external_access vault vault 30008
allow_external_access default gitops-secrets-service 30001
force_password_change
