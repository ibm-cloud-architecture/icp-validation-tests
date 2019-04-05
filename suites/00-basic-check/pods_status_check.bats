#!/usr/bin/env bats
CAPABILITIES=("kubectl")
load ${APP_ROOT}/libs/sert-compat.bash

@test "Pods status | All pods status check" {
    # Check all pods satus
      pods_status=$($KUBECTL get pods --all-namespaces | grep -v Running | grep -v Completed | wc -l)
      [[ $pods_status -eq 1 ]]

}
