#!/usr/bin/env bats

# This will load the helpers.
load ${APP_ROOT}/libs/sert-compat.bash

@test "Kube DNS | Check the DNS Pod status" {
  # Check all pods satus
  _desired_number=$($KUBECTL get ds -n kube-system kube-dns  -ojsonpath={.status.desiredNumberScheduled})
  _available_number=$($KUBECTL get ds -n kube-system kube-dns  -ojsonpath={.status.numberAvailable})
  _ready_number=$($KUBECTL get ds -n kube-system kube-dns  -ojsonpath={.status.numberReady})
  [[ $_desired_number == $_available_number && $_ready_number == $_available_number ]]
}

@test "Kube DNS | Check if dns works" {
  # Select one of pod to check the dns result
  _test_pod_name=$($KUBECTL get pods -n kube-system -l k8s-app=platform-ui --no-headers | tail -n 1 | awk '{print $1}')
  _dns_service_ip=$($KUBECTL get service -n kube-system kube-dns --no-headers | awk '{print $3}')
  _dns_results=$($KUBECTL exec -n kube-system $_test_pod_name nslookup kube-dns 2>/dev/null | grep -i "Address 1: " | awk -F ': ' '{print $2}' | awk '{print $1}')
  [[ $_dns_service_ip == $_dns_results ]]
}
