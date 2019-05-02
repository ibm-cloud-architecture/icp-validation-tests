#!/usr/bin/env bats
CAPABILITIES=("kubectl" "namespace")

# This will load helpers to be compatible with icp-sert-bats
load ${APP_ROOT}/libs/sert-compat.bash
load ${APP_ROOT}/libs/sequential-helpers.bash
load ${APP_ROOT}/libs/wait-helper.bash

create_environment() {
    # Create batch job
    $KUBECTL apply -f $sert_bats_workdir/suites/01-kubernetes/template/batch-job.yaml --namespace=${NAMESPACE}
}

destroy_environment() {

  # Ensure job is properly cleaned up
  $KUBECTL delete jobs -l job-name=pi --namespace=${NAMESPACE} --ignore-not-found --force --grace-period=0
}

@test "Batch Job | Verify batch job created" {
    batchjobs_data=$($KUBECTL get jobs -l job-name=pi --no-headers --namespace=${NAMESPACE} | wc -l )
    # since wc -l has strange formatting we'll run it through bash aritmathic $((X+0)) to fix that
    [[ $(($batchjobs_data+0)) -gt 0 ]]
}

@test "Batch Job | Verify the jobs status" {
   # Check the jobs status

  wait_for -t 120 -c "$KUBECTL get jobs -l job-name=pi --namespace=${NAMESPACE} -o jsonpath='{.items[0].status.succeeded}'" -o "1"

}

@test "Batch Job | Verify the batch job value" {
   # Check the batch job value
   job_data=""
   delta_data=""
   job_pod=""
   if [[ ! -z "$K8S_SERVERVERSION_STR" ]]; then
     if [[ $K8S_SERVERVERSION_MAJOR -eq 1  && "$K8S_SERVERVERSION_MINOR" -lt 10 ]]; then
       showall="--show-all"
     else
       # --show-all was deprecated in kubernetes 1.10: https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG-1.10.md
       showall=""
     fi
   fi

   for t in $(seq 1 50)
   do
       job_pod=$($KUBECTL get pods --namespace=${NAMESPACE} ${showall} --selector=job-name=pi --output=jsonpath={.items..metadata.name})
       job_data=$($KUBECTL logs --namespace=${NAMESPACE} $job_pod)
       if [[ $job_data == 3.1415*  ]]; then
           echo "The batch job value is correct."
           break
       fi
       sleep 5
   done

   [[ $job_data == 3.1415* ]]
}
