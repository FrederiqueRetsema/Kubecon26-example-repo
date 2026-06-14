#!/bin/bash

NAMESPACE=06-policy-engines

function deploy() {
    SUBDIR=$1

    DIR="/clone/Kubecon26-example-repo/examples/06-policy-engines"
    cd $DIR

}

function create-namespace() {
  NAME=$1

  kubectl create namespace "${NAME}"
  kubectl label namespace "${NAME}" example="${NAMESPACE}"
}

create-namespace "${NAMESPACE}"
create-namespace "${NAMESPACE}-VAP"
create-namespace "${NAMESPACE}-no-policies"
kubectl label namespace "${NAME}-no-policies" policy-enforcement=disabled

deploy 01-ValidatingAdmissionPolicy
