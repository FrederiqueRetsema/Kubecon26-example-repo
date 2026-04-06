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

function allow_external_access() {
  NAMESPACE=$1
  SERVICE=$2
  EXTERNAL_PORT=$3

  kubectl patch svc "$SERVICE" -n "$NAMESPACE" -p '{"spec": {"type": "NodePort"}}'
  kubectl patch svc "$SERVICE" -n "$NAMESPACE" --type json -p "[{\"op\": \"add\", \"path\": \"/spec/ports/0/nodePort\", \"value\":$EXTERNAL_PORT}]"
}

ARGOCD_PWD=$(argocd admin initial-password -n argocd | head -n 1)
ARGOCD_IP=$(kubectl get svc -n argocd argocd-server | tail -n 1 | awk '{print $3}')
echo "Pwd admin = $ARGOCD_PWD"

argocd login $ARGOCD_IP:80 --username admin --password $ARGOCD_PWD --insecure

sleep 10

argocd app create vault-secret-store \
--project default \
--repo https://github.com/FrederiqueRetsema/Kubecon26-example-repo \
--path "./examples/03-refresh-secrets/manifests/vault-integration" \
--sync-policy auto \
--dest-namespace external-secrets-aws \
--dest-server https://kubernetes.default.svc

argocd_wait_for_healty vault-secret-store
sleep 5

echo "Should show READY: True"
kubectl get clustersecretstore vault-backend 

argocd app create my-secret-app \
--project default \
--repo https://github.com/FrederiqueRetsema/Kubecon26-example-repo \
--path "./examples/02-refresh-secrets/manifests/app" \
--sync-policy auto \
--sync-option CreateNamespace=true \
--dest-namespace example-refresh-secrets \
--dest-server https://kubernetes.default.svc                  

allow_external_access vault vault 30008
allow_external_access example-refresh-secrets gitops-secrets-service 30001
