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

function wait_for_full_line() {
    SCRIPT=$1
    EXPECTED_WORDCOUNT=$2

    OUTPUT=$(kubectl get -f "$SCRIPT" | tail -n 1)
    REAL_WORDCOUNT=$(echo "$OUTPUT" | wc -w)
    while [[ "$EXPECTED_WORDCOUNT" != "$REAL_WORDCOUNT" ]]
    do
        echo "Output: $OUTPUT"
        echo "Expected wordcount $EXPECTED_WORDCOUNT != Real wordcount $REAL_WORDCOUNT"
        echo "Wait 2 seconds..."
        sleep 2
        OUTPUT=$(kubectl get -f "$SCRIPT" | tail -n 1)
        REAL_WORDCOUNT=$(echo "$OUTPUT" | wc -w)
    done
}

function wait_for_result() {
    SCRIPTNAME=$1
    RESULT_NAME=$2
    EXPECTED_RESULT=$3
    POSITION=$4

    OUTPUT=$(kubectl get -f "$SCRIPTNAME" | tail -n 1)
    REAL_RESULT=$(echo "$OUTPUT" | awk '{print $'$POSITION'}')
    while [[ "$REAL_RESULT" != "$EXPECTED_RESULT" ]]
    do
        echo "Output: $OUTPUT"
        echo "Expected $RESULT_NAME $EXPECTED_RESULT != Real $RESULT_NAME $REAL_RESULT"
        echo "Wait 2 seconds..."
        sleep 2
        OUTPUT=$(kubectl get -f "$SCRIPTNAME" | tail -n 1)
        REAL_RESULT=$(echo "$OUTPUT" | awk '{print $'$POSITION'}')
    done

    echo "Output: $OUTPUT"
    echo "$SCRIPTNAME : $RESULT_NAME = $REAL_RESULT"
}

deploy() {
    SCRIPTNAME=$1
    WORDS_IN_FULL_LINE=$2
    RESULT_NAME=$3
    EXPECTED_RESULT_VALUE=$4
    RESULT_POSITION_IN_LINE=$5

    kubectl apply -f "$SCRIPTNAME"
    wait_for_full_line "$SCRIPTNAME" "$WORDS_IN_FULL_LINE"
    wait_for_result "$SCRIPTNAME" "$RESULT_NAME" "$EXPECTED_RESULT_VALUE" "$RESULT_POSITION_IN_LINE"
}

function load_scripts_composition() {
    DIR="/clone/Kubecon26-example-repo/examples/04-crossplane/composition"
    cd $DIR

    deploy "01-fn.yml"          5 "health"      "True"     3
    deploy "02-xrd.yml"         3 "established" "True"     2
    deploy "03-composition.yml" 4 "name"        "app-yaml" 1
    deploy "04-app.yml"         5 "ready"       "True"     3
    cd -
}

kubectl create namespace 04-crossplane
install_aws_secrets

# Only load scripts that don't create AWS resources (they will stay in AWS when
# you delete the cluster without deleting the resources within Kubernetes first)
load_scripts_composition
