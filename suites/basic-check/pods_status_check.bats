#!/usr/bin/env bats


@test "Pods status | All pods status check" {
    # Check all pods satus
      pods_status=$($KUBECTL get pods --all-namespaces | grep -v Running | grep -v Completed | wc -l)
      [[ $pods_status -eq 1 ]]

}
