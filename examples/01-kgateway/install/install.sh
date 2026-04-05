#!/bin/bash

kubectl create namespace example-kgateway

cd /clone/Kubecon26-example-repo/examples/01-kgateway
ls -1 *.yaml | awk '{print "kubectl apply -f "$1}'| bash 
