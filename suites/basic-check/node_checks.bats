#!/usr/bin/env bats

@test "Cluster nodes | All nodes ready" {
  nodes_notready="$($KUBECTL  get nodes --no-headers | grep -i NotReady | wc -l)"
  [[ "$nodes_notready" -eq 0 ]]
}
