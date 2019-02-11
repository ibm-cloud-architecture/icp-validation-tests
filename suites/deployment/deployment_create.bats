#!/usr/bin/env bats

# This will load the helpers.
load ../../helpers

@test "Deployment Create | Create deployment with replicas 1 and image policy was IfNotPresent" {
    # Clean up
    $KUBECTL delete deployment -n ${NAMESPACE} -lrun=nginx --ignore-not-found
    for t in $(seq 1 50)
    do
      number=$($KUBECTL get deployment --ignore-not-found --no-headers --namespace=${NAMESPACE} | wc -l)
      if [[ $number == 0 ]]; then
         echo "The deployment was removed"
         break
      fi
      sleep 5
    done

    # Create deployment with 1 replicas
    $KUBECTL run nginx --replicas=1 --image-pull-policy=IfNotPresent --image="nginx" --namespace=${NAMESPACE} --port=80


    deployment_data=$($KUBECTL get deployment -lrun=nginx --namespace=${NAMESPACE} --no-headers | wc -l)
    [[ $deployment_data -ne 0 ]]
}

@test "Deployment Create | Verify the deployment available number was correct" {
    # Check the deployment AVAILABLE number
    num_available=0
    for t in $(seq 1 50)
    do
        num_available=$($KUBECTL get deployment  -lrun=nginx --namespace=${NAMESPACE} --no-headers | awk '{print $5}')
        if [[ $num_available -eq 1 ]]; then
            echo "The deployment has created successful."
            break
        fi
        sleep 5
    done
    [[ $num_available -eq 1 ]]
}

@test "Deployment Create | Verify the pod status" {
   # Check the pod status
   pod_status=""
   for t in $(seq 1 50)
   do
       pod_status=$($KUBECTL get pods -lrun=nginx --namespace=${NAMESPACE} --no-headers | awk '{print $3}')
       if [[ $pod_status == 'Running' ]]; then
           echo "The pod status was Running."
           break
       fi
       sleep 5
   done

   [[ $pod_status == 'Running' ]]
}

@test "Deployment Create | Verify the pod number" {
    #Check the pod number
    num_podrunning=0
    desired_pod=$($KUBECTL get pods -lrun=nginx --namespace=${NAMESPACE} --no-headers | awk '{print $2}' | awk -F '/' '{print $2}')
    for t in $(seq 1 50)
    do
        num_podrunning=$($KUBECTL get pods -lrun=nginx --namespace=${NAMESPACE} --no-headers | awk '{print $2}' | awk -F '/' '{print $1}')
        if [[ $num_podrunning == $desired_pod ]]; then
            echo "The pod was running"
            break
        fi
        sleep 5
    done

    [[ $num_podrunning == $desired_pod ]]
}

@test "Deployment Create | Delete the deployment nginx" {
    # Delete the deployment nginx
     $KUBECTL delete deployments/nginx --namespace=${NAMESPACE}
     deployment_data=$($KUBECTL get deployment -lrun=nginx --namespace=${NAMESPACE} --no-headers | wc -l)
    [[ $deployment_data -eq 0 ]]
}
