#!/bin/bash

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
  ACCESS_KEY_S3=$(get_access_key_from_secret kubecon26-crossplane-credentials)
  SECRET_ACCESS_KEY_S3=$(get_secret_access_key_from_secret kubecon26-crossplane-credentials)

  echo "[default]" > /tmp/$$
  echo "aws_access_key_id = $ACCESS_KEY_S3" >> /tmp/$$
  echo "aws_secret_access_key = $SECRET_ACCESS_KEY_S3" >> /tmp/$$

  kubectl create secret generic aws-secret \
    --namespace=crossplane-system \
    --from-file=creds=/tmp/$$

  rm /tmp/$$
}

kubectl create namespace 04-crossplane
install_aws_secrets

# Don't load scripts for Crossplane: when you delete the cluster, the objects that crossplane
# creates will stay.
