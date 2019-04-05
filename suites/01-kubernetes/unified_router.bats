#!/usr/bin/env bats
CAPABILITIES=("kubectl")
# This will load helpers to be compatible with icp-sert-bats
load ${APP_ROOT}/libs/sert-compat.bash

get_num_master

@test "unified-router | Make sure unified-router started on each of master node" {
   # Unified-router was daemonset and should be started on each of master node
   # Get the pod number
   pod_number=$($KUBECTL get pods -lk8s-app=unified-router -n kube-system --no-headers | wc -l | sed 's/^ *//')

   [[ $pod_number == $node_number ]]
}

@test "unified-router | Make sure unified-router was Running on each of master node" {
    # Check the status of unified-router pods
    for a in $(seq 1 $node_number); do
        pod_status=$($KUBECTL get pods -lk8s-app=unified-router -n kube-system --no-headers | awk '{print $3}'| tail -n $a | head -n 1)
        [[ $pod_status == 'Running' ]]
    done
}

@test "unified-router | Check unified-router pod startup" {
    # Check the pod number of unified-router to make sure the pod startup
    for a in $(seq 1 $node_number); do
        required_pod=$($KUBECTL get pods -lk8s-app=unified-router -n kube-system --no-headers | tail -n $a | head -n 1 | awk '{print $2}' | awk -F / '{print $2}')

        running_pod=$($KUBECTL get pods -lk8s-app=unified-router -n kube-system --no-headers | tail -n $a | head -n 1 | awk '{print $2}' | awk -F / '{print $1}')

        [[ $required_pod == $running_pod ]]
    done
}
