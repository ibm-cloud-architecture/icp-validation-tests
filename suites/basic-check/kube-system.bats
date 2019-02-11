#!/usr/bin/env bats

# This will load the helpers.
load ../../helpers

@test "kube-system | All pods healthy" {
  pods_status="$($KUBECTL -n kube-system get pods --no-headers | awk '!/Running/ && !/Completed/' | wc -l)"
  [[ "$pods_status" -eq 0 ]]
}

@test "kube-system | Deployments have all pods available" {
  status="$($KUBECTL kubectl -n kube-system get deployment --no-headers | awk ' BEGIN { fails=0 } { if ($2-$5 > 0) { fails+=1 } } END {  print fails }')"
  [[ "$status" -eq 0 ]]
}

@test "kube-system | Statefulsets have all pods available" {
  status="$($KUBECTL -n kube-system get statefulset --no-headers | awk ' BEGIN { fails=0 } { if ($2-$3 > 0) { fails+=1 } } END {  print fails }')"
  [[ "$status" -eq 0 ]]
}

@test "kube-system | Daemonsets have all pods available" {
  status="$($KUBECTL -n kube-system get daemonset --no-headers | awk ' BEGIN { fails=0 } { if ($2-$6 > 0) { fails+=1 } } END {  print fails }')"
  [[ "$status" -eq 0 ]]
}

@test "kube-system | Replicasets have all pods available" {
  status="$($KUBECTL -n kube-system get replicaset --no-headers | awk ' BEGIN { fails=0 } { if ($2-$4 > 0) { fails+=1 } } END {  print fails }')"
  [[ "$status" -eq 0 ]]
}

@test "kube-system | All jobs have completed successfully" {
  status="$($KUBECTL -n kube-system get jobs --no-headers | awk ' BEGIN { fails=0 } { if ($2-$3 > 0) { fails+=1 } } END {  print fails }')"
  [[ "$status" -eq 0 ]]
}
