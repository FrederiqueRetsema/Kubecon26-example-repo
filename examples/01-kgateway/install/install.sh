#!/bin/bash

MAINDIR=/clone/Kubecon26-example-repo/examples/01-kgateway

function deploy() {
    DIR=$1

    cd "${MAINDIR}/${DIR}"
    ls -1 *.yml | sort | awk '{print "kubectl apply -f "$1}'| bash
}

kubectl create namespace 01-kgateway

deploy "http-route"
deploy "cert-manager"

