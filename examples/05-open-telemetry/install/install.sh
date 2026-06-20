#!/bin/bash

MAIN_DIR="/clone/Kubecon26-example-repo/examples/05-open-telemetry/"

function load_scripts() {
  DIR="${MAIN_DIR}/$1"

  cd $DIR
  ls -1 *yml | awk '{print "kubectl apply -n monitoring -f "$1}' | bash
}

load_scripts grafana-dashboard
