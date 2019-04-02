#!/usr/bin/env bats
CAPABILITIES=("namespace")

# This will load helpers to be compatible with icp-sert-bats
load ${APP_ROOT}/libs/sert-compat.bash

setup() {
  if [[ "$BATS_TEST_NUMBER" -eq 1 ]]; then
    # Create batch job
    $KUBECTL apply -f $sert_bats_workdir/suites/01-kubernetes/template/batch-job.yaml --namespace=${NAMESPACE}
  fi
}

teardown() {
  if [[ "$BATS_TEST_NUMBER" -eq ${#BATS_TEST_NAMES[@]} ]]; then
    # Ensure job is properly cleaned up
    $KUBECTL delete jobs -l job-name=pi --namespace=${NAMESPACE} --ignore-not-found --force --grace-period=0
    for t in $(seq 1 50)
    do
       job_num=$($KUBECTL get jobs -l job-name=pi  --no-headers --namespace=${NAMESPACE} | awk '{print $3}')
       if [[ $job_num -eq 0 ]]; then
           echo "The batch job was delete successful."
           break
       fi
       sleep 5
    done
  fi
}

@test "Batch Job | Verify batch job created" {
    batchjobs_data=$($KUBECTL get jobs -l job-name=pi --no-headers --namespace=${NAMESPACE} | wc -l | sed 's/^ *//')
    [[ $batchjobs_data -ne 0 ]]
}

@test "Batch Job | Verify the jobs status" {
   # Check the jobs status
   job_num=""
   for t in $(seq 1 50)
   do
     job_num=$($KUBECTL get jobs -l job-name=pi  --no-headers --namespace=${NAMESPACE}  -oyaml | grep succeeded | awk '{print $2}')
     if [[ $job_num -eq 1 ]]; then
       echo "The batch job status was successful."
       break
      fi
      sleep 2
   done

   [[ $job_num -eq 1 ]]
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

@test "Batch Job | Delete batchjob" {
    # Delete batchjob
    $KUBECTL delete jobs/pi --namespace=${NAMESPACE} --ignore-not-found

    batchjobs_data=$($KUBECTL get jobs -l job-name=pi --namespace=${NAMESPACE} --no-headers | wc -l | sed 's/^ *//')
    [[ $batchjobs_data -eq 0 ]]
}
