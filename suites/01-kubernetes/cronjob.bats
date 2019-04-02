#!/usr/bin/env bats
CAPABILITIES=("namespace")

# This will load helpers to be compatible with icp-sert-bats
load ${APP_ROOT}/libs/sert-compat.bash

setup() {

  if [[ "$BATS_TEST_NUMBER" -eq 1 ]]; then
    client_versions
    if [[ $ignor_version != '1.7' ]]; then
      $KUBECTL apply -f $sert_bats_workdir/suites/01-kubernetes/template/cronjob-1.7.yaml --namespace=${NAMESPACE}
    else
      $KUBECTL apply -f $sert_bats_workdir/suites/01-kubernetes/template/cronjob.yaml --namespace=${NAMESPACE}
    fi

    for t in $(seq 1 50)
    do
      cronjobs_data=$($KUBECTL get cronjob --namespace=${NAMESPACE} --no-headers | wc -l | sed 's/^ *//')
      if [[ $cronjobs_data != 0 ]]; then
         echo "The cronjob was created"
         break
      fi
      sleep 5
    done
  fi
}

teardown() {
  if [[ "$BATS_TEST_NUMBER" -eq ${#BATS_TEST_NAMES[@]} ]]; then
    client_versions
    if [[ $ignor_version != '1.7' ]]; then
      $KUBECTL delete -f $sert_bats_workdir/suites/01-kubernetes/template/cronjob-1.7.yaml --namespace=${NAMESPACE} --ignore-not-found
    else
      $KUBECTL delete -f $sert_bats_workdir/suites/01-kubernetes/template/cronjob.yaml --namespace=${NAMESPACE} --ignore-not-found
    fi
    # Clean up
    for t in $(seq 1 50)
    do
      number=$($KUBECTL get cronjob --namespace=${NAMESPACE} --no-headers | wc -l | sed 's/^ *//')
      if [[ $number == 0 ]]; then
         echo "The cronjob was removed"
         break
      fi
      sleep 5
    done
  fi
}

@test "CronJob | Verify the cronjob status" {
   # Check the jobs status
   job_num=""
   for t in $(seq 1 50)
   do
       job_num=$($KUBECTL get cronjob --namespace=${NAMESPACE} --no-headers | wc -l | sed 's/^ *//')
       if [[ $job_num -ne 0 ]]; then
           echo "The cronjob status was successful."
           break
       fi
       sleep 5
   done

   [[ $job_num -ne 0 ]]
}

@test "CronJob | Delete cronjob" {

  client_versions
  if [[ $ignor_version != '1.7' ]]; then
    $KUBECTL delete -f $sert_bats_workdir/suites/01-kubernetes/template/cronjob-1.7.yaml --namespace=${NAMESPACE} --ignore-not-found
  else
    $KUBECTL delete -f $sert_bats_workdir/suites/01-kubernetes/template/cronjob.yaml --namespace=${NAMESPACE} --ignore-not-found
  fi

  cronjobs_data=$($KUBECTL get cronjob --namespace=${NAMESPACE} --no-headers | wc -l | sed 's/^ *//')
  [[ $cronjobs_data -eq 0 ]]

}
