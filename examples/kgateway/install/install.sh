#!/bin/bash

kubectl create namespace example-kgateway

cd /clone/Kubecon26-example-repo/examples/kgateway
ls -1 | grep -v *.md | grep -v install | awk '{print "kubectl apply -f "$1}'| bash 
