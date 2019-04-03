#!/usr/bin/env bats
CAPABILITIES=("namespace")

# This will load helpers to be compatible with icp-sert-bats
load ${APP_ROOT}/libs/sert-compat.bash
load ${APP_ROOT}/libs/sequential-helpers.bash

create_environment() {
  $KUBECTL apply -f $sert_bats_workdir/suites/01-kubernetes/template/cronjob.yaml --namespace=${NAMESPACE}
}

environment_ready() {
  $KUBECTL get cronjob -n ${NAMESPACE} | grep hello
  retval=$?
  if [[ $retval -eq 0 ]]; then
    return 0
  else
    return 1
  fi
}

destroy_environment() {
  $KUBECTL delete -f $sert_bats_workdir/suites/01-kubernetes/template/cronjob.yaml --namespace=${NAMESPACE}
}

@test "CronJob | Verify the cronjob created" {
   # Check the jobs status
   $KUBECTL get cronjob -n ${NAMESPACE} | grep hello
   retval=$?
   # Retval will reflect whether grep found the value hello which is the name of the job
   [[ $retval -eq 0 ]]
}

@test "CronJob | job has run successfully" {
  # Check for the output on the cronjob container

  # Get a list of jobs
  jobs=( $KUBECTL -n ${NAMESPACE} get cronjob hello -o jsonpath='{.status.active..name}' )

  # Get the log output of the last jobs pod
  podlog=$( $KUBECTL -n ${NAMESPACE} logs -l job-name=${jobs[-1]})
  
  [[ "$podlog" =~ "Hello from the Kubernetes cluster" ]]
}
