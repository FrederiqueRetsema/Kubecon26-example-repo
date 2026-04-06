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
                                               --namespace 03-example-refresh-secrets-aws

  ACCESS_KEY_SECRETSMANAGER=$(get_access_key_from_secret kubecon26-external-secrets-operator-secrets-credentials)
  SECRET_ACCESS_KEY_SECRETSMANAGER=$(get_secret_access_key_from_secret kubecon26-external-secrets-operator-secrets-credentials)

  kubectl create secret generic secretsmanager --from-literal=access_key=$ACCESS_KEY_SECRETSMANAGER \
                                               --from-literal=secret_access_key=$SECRET_ACCESS_KEY_SECRETSMANAGER \
                                               --namespace 03-example-refresh-secrets-aws
}

function load_scripts() {
  DIR=$1

  cd $DIR
  ls -1 *yml | awk '{print "kubectl apply -n 03-example-refresh-secrets-aws -f "$1}' | bash
}

kubectl create namespace 03-example-refresh-secrets-aws
install_aws_secrets

load_scripts /clone/Kubecon26-example-repo/examples/03-refresh-secrets-aws/manifests-secretsmanager/secretsmanager-integration
load_scripts /clone/Kubecon26-example-repo/examples/03-refresh-secrets-aws/manifests-ssm-parameters/ssm-parameters-integration

sleep 5

echo "Should show READY: True"
kubectl get clustersecretstore 

load_scripts /clone/Kubecon26-example-repo/examples/03-refresh-secrets-aws/manifests-secretsmanager/app
load_scripts /clone/Kubecon26-example-repo/examples/03-refresh-secrets-aws/manifests-ssm-parameters/app
