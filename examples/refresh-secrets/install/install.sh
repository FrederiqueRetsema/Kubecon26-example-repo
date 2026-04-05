export HOME="/root"

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

ARGOCD_PWD=$(argocd admin initial-password -n argocd | head -n 1)
ARGOCD_IP=$(kubectl get svc -n argocd argocd-server | tail -n 1 | awk '{print $3}')
echo "Pwd admin = $ARGOCD_PWD"

argocd login $ARGOCD_IP:80 --username admin --password $ARGOCD_PWD --insecure
argocd app create vault \
--project default \
--repo https://helm.releases.hashicorp.com \
--helm-chart vault \
--revision 0.32.0 \
--sync-policy auto \
--sync-option CreateNamespace=true \
--parameter server.dev.enabled=true \
--dest-namespace vault \
--dest-server https://kubernetes.default.svc

argocd_wait_for_healty vault

kubectl exec -i vault-0 -n vault -- /bin/sh <<EOF
vault login root

# Write the demo credentials
vault kv put secret/mysql_credentials \
url="mysql.example.com:3306" \
username="my_demo_user" \
password="my_demo_password"

# Enable Kubernetes auth
vault auth enable kubernetes
vault write auth/kubernetes/config \
kubernetes_host=https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT

# Policy and role for ESO
vault policy write eso-read-policy - <<EOF2
path "secret/*" {
capabilities = [ "read", "list" ]
}
EOF2
vault write auth/kubernetes/role/demo \
bound_service_account_names=* \
bound_service_account_namespaces=* \
policies=eso-read-policy \
ttl=24h

exit
EOF

sleep 10

helm repo add external-secrets https://charts.external-secrets.io

helm install external-secrets \
    external-secrets/external-secrets \
    -n external-secrets \
    --create-namespace

sleep 10

argocd app create vault-secret-store \
--project default \
--repo https://github.com/FrederiqueRetsema/Kubecon26-example-repo \
--path "./examples/refresh-secrets/manifests/vault-integration" \
--sync-policy auto \
--dest-namespace external-secrets \
--dest-server https://kubernetes.default.svc

argocd_wait_for_healty vault-secret-store
sleep 5

echo "Should show READY: True"
kubectl get clustersecretstore vault-backend  # should show READY: True

argocd app create my-secret-app \
--project default \
--repo https://github.com/FrederiqueRetsema/Kubecon26-example-repo \
--path "./examples/refresh-secrets/manifests/app" \
--sync-policy auto \
--dest-namespace default \
--dest-server https://kubernetes.default.svc                  
