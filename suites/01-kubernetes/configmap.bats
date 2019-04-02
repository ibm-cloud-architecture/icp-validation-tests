#!/usr/bin/env bats
CAPABILITIES=("namespace")

# This will load helpers to be compatible with icp-sert-bats
load ${APP_ROOT}/libs/sert-compat.bash

setup() {
  if [[ "$BATS_TEST_NUMBER" -eq 1 ]]; then
    $KUBECTL apply -f $sert_bats_workdir/suites/01-kubernetes/template/configmap-redis.yaml -n ${NAMESPACE}

    for t in $(seq 1 50)
    do
      num_podrunning=$($KUBECTL get pods redis --namespace=${NAMESPACE} --no-headers | awk '{print $2}' | awk -F '/' '{print $1}')
      desired_pod=$($KUBECTL get pods redis --namespace=${NAMESPACE} --no-headers | awk '{print $2}' | awk -F '/' '{print $2}')
      if [[ $num_podrunning == $desired_pod ]]; then
        echo "The pod was running"
        break
      fi
      sleep 5
    done
  fi
}

teardown() {
  #Clean up when the last case finished
  if [[ "$BATS_TEST_NUMBER" -eq ${#BATS_TEST_NAMES[@]} ]]; then
    $KUBECTL delete -f $sert_bats_workdir/suites/01-kubernetes/template/configmap-redis.yaml -n ${NAMESPACE} --ignore-not-found
  fi
}

@test "Configmap | Redis with configmap" {
    $KUBECTL exec -n ${NAMESPACE} redis redis-cli CONFIG GET maxmemory | grep maxmemory
    [[ $? -eq 0 ]]
}
