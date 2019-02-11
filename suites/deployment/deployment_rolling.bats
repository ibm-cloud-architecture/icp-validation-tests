#!/usr/bin/env bats

# This will load the helpers.
load ../../helpers

@test "Deployment Rollout | Rollout the deployment" {
    # Create deployment with 1 replicas
    $KUBECTL delete deployment -n ${NAMESPACE} -lrun=nginx-roll --ignore-not-found
    for t in $(seq 1 50)
    do
      number=$($KUBECTL get deployment --ignore-not-found --no-headers --namespace=${NAMESPACE} | wc -l)
      if [[ $number == 0 ]]; then
         echo "The deployment was removed"
         break
      fi
      sleep 5
    done


   $KUBECTL run nginx-roll --replicas=1 --image-pull-policy=IfNotPresent --image="nginx" --namespace=${NAMESPACE}

    for t in $(seq 1 50)
    do
        deployment_data=$($KUBECTL get deployment -lrun=nginx-roll --namespace=${NAMESPACE} --no-headers | wc -l)
        if [[ $deployment_data -eq 1 ]]; then
           echo "The deployment has been created successful."
           break
        fi
        sleep 5
    done

    desired_pod=$($KUBECTL get pods -lrun=nginx-roll --namespace=${NAMESPACE} --no-headers | awk '{print $2}' | awk -F '/' '{print $2}')
    for t in $(seq 1 50)
    do
        num_podrunning=$($KUBECTL get pods -lrun=nginx-roll --namespace=${NAMESPACE} --no-headers | awk '{print $2}' | awk -F '/' '{print $1}')
        if [[ $num_podrunning == $desired_pod ]]; then
            echo "The pod was running"
            break
        fi
        sleep 5
    done
    [[ $num_podrunning == $desired_pod ]]

    # Start rollout the deployment
    $KUBECTL patch deployment/nginx-roll --namespace=${NAMESPACE} -p'{"spec":{"template":{"spec":{"containers":[{"name":"nginx-roll","image":"nginx:1.13"}]}}}}'

    [[ $? -eq 0 ]]
}

@test "Deployment Rollout | Check the deployment rollout history" {
    # Check the deployment rollout history
    $KUBECTL rollout history deployment/nginx-roll --namespace=${NAMESPACE} --revision=2

    [[ $? -eq 0 ]]
}

@test "Deployment Rollout | Check the deployment rollout result" {
  #Check the deployment rollout result

  for t in `seq 1 50`
  do
    num_available=$($KUBECTL get deployment -lrun=nginx-roll --namespace=${NAMESPACE} --no-headers| awk '{print $5}')
    if [ $num_available -eq 1 ]; then
      echo "The deployment has rollout successful."
      break
    fi
    sleep 2
  done

  # need to wait for old pod deleted
  for t in `seq 1 50`
  do
    num_pods=$($KUBECTL get pods -lrun=nginx-roll --namespace=${NAMESPACE} --no-headers | wc -l)
    if [ $num_pods -eq 1 ]; then
      echo "the pod created successful"
      break
    fi
    sleep 2
  done

  image_name="nginx:1.13"

  #Get pod name
  pod_name=$($KUBECTL get pods -lrun=nginx-roll --namespace=${NAMESPACE} | tail -n 1 | awk '{print $1}')

  pod_image_name=$($KUBECTL get pods $pod_name --namespace=${NAMESPACE} -o jsonpath="{.spec.containers[*].image}")

  [[ $image_name == $pod_image_name ]]

}
