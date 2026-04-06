export HOME="/root"

function get_access_key_from_secret() {
  SECRET_ID=$1

  ACCESS_KEY=$(aws secretsmanager get-secret-value \
                                    --secret-id $SECRET_ID \
                                    --region ##AWS-Region## \
                                    --query SecretString \
                                    --output text | jq -r '.access_key')
  echo $ACCESS_KEY
}

function get_secret_access_key_from_secret() {
  SECRET_ID=$1

  SECRET_ACCESS_KEY=$(aws secretsmanager get-secret-value \
                                    --secret-id $SECRET_ID \
                                    --region ##AWS-Region## \
                                    --query SecretString \
                                    --output text | jq -r '.secret_access_key')
  echo $SECRET_ACCESS_KEY
}

function install_aws_secrets() {
  ACCESS_KEY_SSM_PARAMETERS=$(get_access_key_from_secret kubecon26-external-secrets-operator-ssm-credentials)
  SECRET_ACCESS_KEY_SSM_PARAMETERS=$(get_secret_access_key_from_secret kubecon26-external-secrets-operator-ssm-credentials)

  kubectl create secret generic ssm-parameters --from-literal=access_key=$ACCESS_KEY_SSM_PARAMETERS \
                                               --from-literal=secret_access_key=$SECRET_ACCESS_KEY_SSM_PARAMETERS \
                                               --namespace example-refresh-secrets-aws

  ACCESS_KEY_SECRETSMANAGER=$(get_access_key_from_secret kubecon26-external-secrets-operator-secrets-credentials)
  SECRET_ACCESS_KEY_SECRETSMANAGER=$(get_secret_access_key_from_secret kubecon26-external-secrets-operator-secrets-credentials)

  kubectl create secret generic secretsmanager --from-literal=access_key=$ACCESS_KEY_SECRETSMANAGER \
                                               --from-literal=secret_access_key=$SECRET_ACCESS_KEY_SECRETSMANAGER \
                                               --namespace example-refresh-secrets-aws
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
      echo "Wait another 10 seconds (app: $APP)"
      sleep 10
  done
}

kubectl create namespace example-refresh-secrets-aws
install_aws_secrets

ARGOCD_PWD=$(argocd admin initial-password -n argocd | head -n 1)
ARGOCD_IP=$(kubectl get svc -n argocd argocd-server | tail -n 1 | awk '{print $3}')
echo "Pwd admin = $ARGOCD_PWD"

argocd login $ARGOCD_IP:80 --username admin --password $ARGOCD_PWD --insecure

sleep 10

argocd app create secretsmanager-secret-store \
--project default \
--repo https://github.com/FrederiqueRetsema/Kubecon26-example-repo \
--path "./examples/03-refresh-secrets-aws/manifests-secretsmanager/secretsmanager-integration" \
--sync-policy auto \
--dest-namespace external-secrets-aws \
--dest-server https://kubernetes.default.svc

argocd app create ssm-parameters-secret-store \
--project default \
--repo https://github.com/FrederiqueRetsema/Kubecon26-example-repo \
--path "./examples/03-refresh-secrets-aws/manifests-ssm-parameters/ssm-parameters-integration" \
--sync-policy auto \
--dest-namespace external-secrets-aws \
--dest-server https://kubernetes.default.svc

argocd_wait_for_healty secretsmanager-secret-store
argocd_wait_for_healty ssm-parameters-secret-store
sleep 5

echo "Should show READY: True"
kubectl get clustersecretstore 

argocd app create my-secret-app-secretsmanager \
--project default \
--repo https://github.com/FrederiqueRetsema/Kubecon26-example-repo \
--path "./examples/03-refresh-secrets-aws/manifests-secretsmanager/app" \
--sync-policy auto \
--sync-option CreateNamespace=true \
--dest-namespace example-refresh-secrets-aws \
--dest-server https://kubernetes.default.svc                  

argocd app create my-secret-app-ssm-parameters \
--project default \
--repo https://github.com/FrederiqueRetsema/Kubecon26-example-repo \
--path "./examples/03-refresh-secrets-aws/manifests-ssm-parameters/app" \
--sync-policy auto \
--sync-option CreateNamespace=true \
--dest-namespace example-refresh-secrets-aws \
--dest-server https://kubernetes.default.svc                  
