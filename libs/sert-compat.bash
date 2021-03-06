#!/usr/bin/env bash

export KUBECTL="kube"
export sert_bats_workdir=${APP_ROOT}
export NAMESPACE=$(kube config get-contexts $(kube config current-context) --no-headers | awk '{print $5}')
export TEST_IMAGE="nginx"

function get_num_master() {
  # the $(( N - 1)) instead of kubectl --no-headers deals with wc -l putting in a ton of spaces
  export node_number=$(( $(kube get nodes -l master=true | wc -l) - 1 ))
}

function get_master_ip() {
  export master_ip=${SERVER}
}

function get_router_https_port() {
  export router_https_port=${ROUTER_HTTPS_PORT}
}

function get_auth_token() {
  export auth_token=$(kube config view -o jsonpath='{.users[?(@.name=="admin")].user.token}')
}
