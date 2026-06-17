#!/bin/bash

NAMESPACE=06-policy-engines

function load_scripts() {
  DIR="/clone/Kubecon26-example-repo/examples/06-policy-engines/$1"
  NAMESPACE=$2

  cd $DIR
  ls -1 *yml | awk '{print "kubectl apply -n 03-refresh-secrets-aws -f "$1}' | bash
}

function create-namespace() {
  NAME=$1

  kubectl create namespace "${NAME}"
  kubectl label namespace "${NAME}" example="${NAMESPACE}"
}

create-namespace "${NAMESPACE}"
create-namespace "${NAMESPACE}-vap"
create-namespace "${NAMESPACE}-kyverno"
create-namespace "${NAMESPACE}-gatekeeper"

create-namespace "${NAMESPACE}-no-policies"
kubectl label namespace "${NAMESPACE}-no-policies" policy-enforcement=disabled

load_scripts 01-ValidatingAdmissionPolicy "${NAMESPACE}-vap"
load_scripts 02-Kyverno                   "${NAMESPACE}-kyverno"
load_scripts 03-Gatekeeper                "${NAMESPACE}-gatekeeper"

