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

function wait_for_healthy() {
    SCRIPTNAME=$1

    OUTPUT=$(kubectl get -f "$SCRIPTNAME" | tail -n 1)
    HEALTHY=$(echo "$OUTPUT" | awk '{print $3}')
    while [[ "$HEALTHY" != "True" ]]
    do
        echo "Output: $OUTPUT"
        echo "Expected health True != Real health $HEALTHY"
        echo "Wait 2 seconds..."
        sleep 2
        OUTPUT=$(kubectl get -f "$SCRIPTNAME" | tail -n 1)
        HEALTHY=$(echo "$OUTPUT" | awk '{print $3}')
    done

    echo "Output: $OUTPUT"
    echo "$SCRIPTNAME = Healthy"
}

function wait_for_established() {
    SCRIPTNAME=$1

    OUTPUT=$(kubectl get -f "$SCRIPTNAME" | tail -n 1)
    ESTABLISHED=$(echo "$OUTPUT" | awk '{print $2}')
    while [[ "$ESTABLISHED" != "True" ]]
    do
        echo "Output: $OUTPUT"
        echo "Expected established True != Real established $ESTABLISHED"
        echo "Wait 2 seconds..."
        sleep 2
        OUTPUT=$(kubectl get -f "$SCRIPTNAME" | tail -n 1)
        ESTABLISHED=$(echo "$OUTPUT" | awk '{print $2}')
    done

    echo "Output: $OUTPUT"
    echo "$SCRIPTNAME = Established"
}

function wait_for_composition() {
    SCRIPTNAME=$1

    OUTPUT=$(kubectl get -f "$SCRIPTNAME" | tail -n 1)
    DEPLOYED=$(echo "$OUTPUT" | grep "not found")
    while [[ "$DEPLOYED" != "" ]]
    do
        echo "Output: $OUTPUT"
        echo "Expected output (no message 'not found') != Real health $OUTPUT"
        echo "Wait 2 seconds..."
        kubectl apply -f "$SCRIPTNAME"
        sleep 2
        OUTPUT=$(kubectl get -f "$SCRIPTNAME" | tail -n 1)
        DEPLOYED=$(echo "$OUTPUT" | grep "not found")
    done

    echo "Output: $OUTPUT"
    echo "$SCRIPTNAME = Deployed"
}

function wait_for_ready() {
    SCRIPTNAME=$1

    OUTPUT=$(kubectl get -f "$SCRIPTNAME" | tail -n 1)
    READY=$(echo "$OUTPUT" | awk '{print $3}')
    while [[ "$READY" != "True" ]]
    do
        echo "Output: $OUTPUT"
        echo "Expected health True != Real health $READY"
        echo "Wait 2 seconds..."
        sleep 2
        OUTPUT=$(kubectl get -f "$SCRIPTNAME" | tail -n 1)
        READY=$(echo "$OUTPUT" | awk '{print $3}')
    done

    echo "Output: $OUTPUT"
    echo "$SCRIPTNAME = Ready"
}

deploy_function() {
    SCRIPTNAME="01-fn.yml"

    kubectl apply -f "$SCRIPTNAME"
    wait_for_full_line "$SCRIPTNAME" 5
    wait_for_healthy "$SCRIPTNAME"
}

function deploy_xrd() {
    SCRIPTNAME="02-xrd.yml"

    kubectl apply -f "$SCRIPTNAME"
    wait_for_full_line "$SCRIPTNAME" 3
    wait_for_established "$SCRIPTNAME"
}

function deploy_composition() {
    SCRIPTNAME="03-composition.yml"

    kubectl apply -f "$SCRIPTNAME"
    wait_for_composition "$SCRIPTNAME"
}

function deploy_app() {
    SCRIPTNAME="04-app.yml"

    kubectl apply -f "$SCRIPTNAME"
    wait_for_full_line "$SCRIPTNAME" 5
    wait_for_ready "$SCRIPTNAME"
}

function load_scripts_composition() {
    DIR="/clone/Kubecon26-example-repo/examples/04-crossplane/composition"
    cd $DIR

    deploy_function
    deploy_xrd
    deploy_composition
    deploy_app
    cd -
}

kubectl create namespace 04-crossplane
install_aws_secrets

# Only load scripts that don't create AWS resources (they will stay in AWS when
# you delete the cluster without deleting the resources within Kubernetes first)
load_scripts_composition
