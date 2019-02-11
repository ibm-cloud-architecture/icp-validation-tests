#!/usr/bin/env bats

# This will load the helpers.
load ../../helpers

setup() {
  if [[ "$BATS_TEST_NUMBER" -eq 1 ]]; then
    # Create batch job
    $KUBECTL create -f suites/batchjob/sample/job.yaml --namespace=${NAMESPACE}
  fi
}

teardown() {
  if [[ "$BATS_TEST_NUMBER" -eq ${#BATS_TEST_NAMES[@]} ]]; then
    # delete batch job
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

@test "Batch Job | Create batch job" {
    batchjobs_data=$($KUBECTL get jobs -l job-name=pi --no-headers --namespace=${NAMESPACE} | wc -l)
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
      sleep 5
   done

   [[ $job_num -eq 1 ]]
}

@test "Batch Job | Verify the batch job value" {
   # Check the batch job value
   job_data=""
   delta_data=""
   job_pod=""
   for t in $(seq 1 50)
   do
       job_pod=$($KUBECTL get pods --namespace=${NAMESPACE} --selector=job-name=pi --output=jsonpath={.items..metadata.name})
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

    batchjobs_data=$($KUBECTL get jobs -l job-name=pi --namespace=${NAMESPACE} --no-headers | wc -l)
    [[ $batchjobs_data -eq 0 ]]
}
