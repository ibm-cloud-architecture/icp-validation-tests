#!/usr/bin/env bats
CAPABILITIES=("namespace")

# This will load helpers to be compatible with icp-sert-bats
load ${APP_ROOT}/libs/sert-compat.bash

setup() {

  if [[ $BATS_TEST_NUMBER -eq 1 ]]; then
    $KUBECTL apply -f $sert_bats_workdir/suites/01-kubernetes/template/daemonset.yaml  --namespace=${NAMESPACE}

    # Waiting for pod startup

    num_podrunning=0
    desired_pod=$($KUBECTL get daemonset --namespace=${NAMESPACE} --no-headers | awk '{print $2}')
    for t in $(seq 1 50)
    do
      num_podrunning=$($KUBECTL get daemonset  --namespace=${NAMESPACE} --no-headers | awk '{print $6}')
      desired_pod=$($KUBECTL get daemonset --namespace=${NAMESPACE} --no-headers | awk '{print $2}')
      if [[ $num_podrunning == $desired_pod ]]; then
        echo "The pod was running"
        break
      fi
      sleep 5
    done
  fi

}

teardown() {

  if [[ "$BATS_TEST_NUMBER" -eq ${#BATS_TEST_NAMES[@]} ]]; then
    # Clean up
    $KUBECTL delete -f $sert_bats_workdir/suites/01-kubernetes/template/daemonset.yaml --ignore-not-found --namespace=${NAMESPACE}
  fi

}

@test "Daemonset | Verify Daemonset" {

  # Waiting for pod startup
  num_podrunning=$($KUBECTL get daemonset  --namespace=${NAMESPACE} --no-headers | awk '{print $6}')
  desired_pod=$($KUBECTL get daemonset --namespace=${NAMESPACE} --no-headers | awk '{print $2}')
  [[ $num_podrunning -eq $desired_pod ]]

}

@test "Daemonset | Edit Daemonset" {

  node_ip=$($KUBECTL get nodes --no-headers -l role=master | grep Ready | awk '{print $1}' | head -n 1)
  echo "node ip is $node_ip"
  # Gain the daemonset name
  ds_name=$($KUBECTL get daemonset --namespace=${NAMESPACE}  -oname |awk -F "/"  '{print $2}' )
  echo "ds name is $ds_name"

  # Gain the daemonset pod name
  pod_name=$($KUBECTL get pods --namespace=${NAMESPACE}  -oname|awk -F "/"  '{print $2}' )

  # Edit the daemonset
  kubectl patch ds/$ds_name --namespace=${NAMESPACE}  -p '{"spec":{"template":{"spec":{"containers":[{"name":"daemonset-test","image":"nginx:1.15.8-alpine"}]}}}}'

  # Check the patch result
  kubectl rollout status ds/daemonset-test --namespace=${NAMESPACE}
  [[ $? -eq 0 ]]
}

@test "Daemonset | Rollback Daemonset" {

  roll_version=$($KUBECTL rollout history daemonset  daemonset-test --namespace=${NAMESPACE}|grep none|head -n 1|awk '{print $1}')
  run $KUBECTL rollout undo daemonset $ds_name --namespace=${NAMESPACE}  --to-revision=$roll_version

  [[ $? -eq 0 ]]
}

@test "Daemonset | Delete Daemonset" {
  # Delete Daemonset

  $KUBECTL delete -f $sert_bats_workdir/suites/01-kubernetes/template/daemonset.yaml  --ignore-not-found --namespace=${NAMESPACE}
  ds_pod_num=$($KUBECTL get daemonset -l name=daemonset-test --namespace=${NAMESPACE}  --no-headers | wc -l | sed 's/^ *//')

  [[ $(($ds_pod_num+0)) -eq 0 ]]
}
