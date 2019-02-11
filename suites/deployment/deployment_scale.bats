#!/usr/bin/env bats

# This will load the helpers.
load ../../helpers

@test "Deployment Scale | Create deployment with replicas 1 and image policy was IfNotPresent" {
    # Clean up
    $KUBECTL delete deployment -n ${NAMESPACE} -lrun=nginx --ignore-not-found
    # Create deployment with 1 replicas
    $KUBECTL run nginx --replicas=1 --image-pull-policy=IfNotPresent --image="nginx" --namespace=${NAMESPACE}

    deployment_data=$($KUBECTL get deployment -lrun=nginx --namespace=${NAMESPACE} --no-headers | wc -l)
    [[ $deployment_data -ne 0 ]]
}

@test "Deployment Scale | Verify the deployment available number was correct" {
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

@test "Deployment Scale | Verify the pod status" {
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

@test "Deployment Scale | Verify the pod number" {
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

@test "Deployment Scale | Scale up the Deployment to 3 replicas" {
    #Scale up the replicas to 3
    $KUBECTL scale --replicas=3 deployment/nginx --namespace=${NAMESPACE}

    desired_pod=$($KUBECTL get deployment -lrun=nginx --namespace=${NAMESPACE} --no-headers | awk '{print $2}')
    for t in $(seq 1 50)
    do
        desired_pod=$($KUBECTL get deployment -lrun=nginx --namespace=${NAMESPACE} --no-headers | awk '{print $2}')
        if [[ $desired_pod -eq 3 ]]; then
            echo "The deployment desired pods number was changed successfully"
            break
        fi
        sleep 5
    done

    [[ $desired_pod -eq 3 ]]
}

@test "Deployment Scale | Scale down the Deployment from 3 to 1" {
    # Scale down the deployment
    $KUBECTL scale --current-replicas=3 --replicas=1 deployment/nginx --namespace=${NAMESPACE}

    desired_pod=$($KUBECTL get deployment -lrun=nginx --namespace=${NAMESPACE} --no-headers | awk '{print $2}')

    for t in $(seq 1 50)
    do
        desired_pod=$($KUBECTL get deployment -lrun=nginx --namespace=${NAMESPACE} --no-headers | awk '{print $2}')
        if [[ $desired_pod -eq 1 ]]; then
            echo "The deployment desired pods number was changed successfully"
            break
        fi
        sleep 5
    done
    [[ $desired_pod -eq 1 ]]
}

@test "Deployment Scale | Delete the deployment nginx" {
    # Delete the deployment nginx
    $KUBECTL delete deployments/nginx --namespace=${NAMESPACE}
    deployment_data=$($KUBECTL get deployment -lrun=nginx --namespace=${NAMESPACE} --no-headers | wc -l)
    [[ $deployment_data -eq 0 ]]
}
