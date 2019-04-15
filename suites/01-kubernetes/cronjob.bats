#!/usr/bin/env bats
CAPABILITIES=("kubectl" "namespace")

# This will load helpers to be compatible with icp-sert-bats
load ${APP_ROOT}/libs/sert-compat.bash
load ${APP_ROOT}/libs/sequential-helpers.bash
load ${APP_ROOT}/libs/wait-helper.bash

create_environment() {
  $KUBECTL apply -f $sert_bats_workdir/suites/01-kubernetes/template/cronjob.yaml --namespace=${NAMESPACE}
}

environment_ready() {
  run bash -c "$KUBECTL get pods -n ${NAMESPACE} | grep hello"
  return $status
}

destroy_environment() {
  $KUBECTL delete -f $sert_bats_workdir/suites/01-kubernetes/template/cronjob.yaml --namespace=${NAMESPACE}
}

@test "CronJob | Verify the cronjob created" {
   # Check the jobs status
   run bash -c "$KUBECTL get cronjob -n ${NAMESPACE} | grep hello"
   # status will reflect whether grep found the value hello which is the name of the job
   assert_or_bail "[[ $status -eq 0 ]]"
}

@test "CronJob | job has run successfully" {

  wait_for -c "$KUBECTL get pods -n ${NAMESPACE} | grep hello" -o "Completed"

  # Get the log output of the last jobs pod
  run bash -c "$KUBECTL get pods -n ${NAMESPACE} | grep hello"

  assert_or_bail "[[ '$output' =~ Completed ]]"
}
