#!/bin/bash

MAINDIR=/clone/Kubecon26-example-repo/examples/01-kgateway

function deploy() {
    DIR=$1

    cd "${MAINDIR}/${DIR}"
    ls -1 *.yml | sort | awk '{print "kubectl apply -f "$1}'| bash
}

kubectl create namespace 01-kgateway
kubectl create namespace 01-kgateway-http-route
kubectl create namespace 01-kgateway-tlsroute-terminate

deploy "http-route"
deploy "cert-manager"

