#!/usr/bin/env bats
CAPABILITIES=("kubectl" "namespace")

# This will load helpers to be compatible with icp-sert-bats
load ${APP_ROOT}/libs/sert-compat.bash
load ${APP_ROOT}/libs/sequential-helpers.bash

create_environment() {
  $KUBECTL run nginx --replicas=1 --labels='run=nginx,test=deployment' --image-pull-policy=IfNotPresent --image=nginx -n ${NAMESPACE} --port=80
}

environment_ready() {
  status=$($KUBECTL -n ${NAMESPACE} get pods -l run=nginx,test=deployment --no-headers | awk '{print $3}')
  if [[ "$status" == "Running" ]]; then
    return 0
  else
    return 1
  fi
}

applicable() {
  # There are some tests that do not work well yet.
  # TODO: Refactor so all tests pass
  return 1
}

destroy_environment() {
  $KUBECTL delete deployment -n ${NAMESPACE} -l run=nginx,test=deployment --ignore-not-found
}


@test "Deployment | Create deployment with replicas 1 and image policy was IfNotPresent" {

  # The create_environment and environment_ready will run before this, so if they haven't
  # timed out, we should be all good
  [[ 1 -eq 1 ]]

}

@test "Deployment | Verify the deployment available number" {
  # Check the deployment AVAILABLE number
  num_available=0
  for t in $(seq 1 50)
  do
    num_available=$($KUBECTL get deployment  -l run=nginx,test=deployment -n ${NAMESPACE} --no-headers | awk '{print $5}')
    if [[ $num_available -eq 1 ]]; then
      echo "The deployment has created successful."
      break
    fi
  sleep 5
  done
  [[ $num_available -eq 1 ]]
}

@test "Deployment | Verify the pod status" {
  # Check the pod status
  pod_status=""
  for t in $(seq 1 50)
  do
    pod_status=$($KUBECTL get pods -l run=nginx,test=deployment -n ${NAMESPACE} --no-headers | awk '{print $3}')
    if [[ $pod_status == 'Running' ]]; then
      echo "The pod status was Running."
      break
    fi
  sleep 5
  done

  [[ $pod_status == 'Running' ]]
}

@test "Deployment | Verify the pod number" {
  #Check the pod number
  num_podrunning=0
  desired_pod=$($KUBECTL get pods -l run=nginx,test=deployment -n ${NAMESPACE} --no-headers | awk '{print $2}' | awk -F '/' '{print $2}')
  for t in $(seq 1 50)
  do
    num_podrunning=$($KUBECTL get pods -l run=nginx,test=deployment -n ${NAMESPACE} --no-headers | awk '{print $2}' | awk -F '/' '{print $1}')
    if [[ $num_podrunning == $desired_pod ]]; then
      echo "The pod was running"
      break
    fi
  sleep 5
  done

  [[ $num_podrunning == $desired_pod ]]
}

@test "Deployment | Rollout the deployment" {

  desired_pod=$($KUBECTL get pods -l run=nginx,test=deployment -n ${NAMESPACE} --no-headers | awk '{print $2}' | awk -F '/' '{print $2}')
  for t in $(seq 1 50)
  do
    num_podrunning=$($KUBECTL get pods -l run=nginx,test=deployment -n ${NAMESPACE} --no-headers | awk '{print $2}' | awk -F '/' '{print $1}')
    if [[ $num_podrunning == $desired_pod ]]; then
      echo "The pod was running"
      break
    fi
  sleep 5
  done

  # Start rollout the deployment
  $KUBECTL patch deployment/nginx -n ${NAMESPACE} -p'{"spec":{"template":{"spec":{"containers":[{"name":"nginx","image":"nginx:1.15.8-alpine"}]}}}}'

  [[ $? -eq 0 ]]
}

@test "Deployment | Check the deployment rollout history" {
  # Check the deployment rollout history
  _new_image=$($KUBECTL rollout history deployment/nginx -n ${NAMESPACE} --revision=2 -ojsonpath={.spec.template.spec.containers[0].image})

  [[ $_new_image == 'nginx:1.15.8-alpine' ]]
}

@test "Deployment | Check the deployment rollout result" {
  #Check the deployment rollout result
  for t in `seq 1 50`
  do
    num_available=$($KUBECTL get deployment -l run=nginx,test=deployment -n ${NAMESPACE} --no-headers| awk '{print $5}')
    if [ $num_available -eq 1 ]; then
      echo "The deployment has rollout successful."
      break
    fi
    sleep 2
  done

  # need to wait for old pod deleted
  for t in `seq 1 50`
  do
    num_pods=$($KUBECTL get pods -l run=nginx,test=deployment -n ${NAMESPACE} --no-headers | wc -l | sed 's/^ *//')
    if [ $num_pods -eq 1 ]; then
      echo "the pod created successful"
      break
    fi
    sleep 2
  done

  #Get pod name
  pod_name=$($KUBECTL get pods -l run=nginx,test=deployment -n ${NAMESPACE} | tail -n 1 | awk '{print $1}')

  pod_image_name=$($KUBECTL get pods $pod_name -n ${NAMESPACE} -o jsonpath="{.spec.containers[*].image}")

  [[ $pod_image_name == 'nginx:1.15.8-alpine' ]]

}

@test "Deployment | Rollback the Deployment" {

  $KUBECTL rollout undo deployment/nginx -n ${NAMESPACE} --to-revision 1

  for t in `seq 1 50`
  do
    num_available=$($KUBECTL get deployment -l run=nginx,test=deployment -n ${NAMESPACE} --no-headers| awk '{print $5}')
    if [ $num_available -eq 1 ]; then
      echo "The deployment has rollback successful."
      break
    fi
    sleep 2
  done

  # need to wait for old pod deleted
  for t in `seq 1 50`
  do
    num_pods=$($KUBECTL get pods -l run=nginx,test=deployment -n ${NAMESPACE} --no-headers | grep Running | wc -l | sed 's/^ *//')
    if [ $num_pods -eq 1 ]; then
      echo "the pod created successful"
      break
    fi
    sleep 2
  done

  #Get pod name
  pod_name=$($KUBECTL get pods -l run=nginx,test=deployment -n ${NAMESPACE} | tail -n 1 | awk '{print $1}')
  echo $pod_name

  pod_image_name=$($KUBECTL get pods $pod_name -n ${NAMESPACE} -o jsonpath="{.spec.containers[*].image}")
  echo $pod_image_name
  echo $TEST_IMAGE

  [[ ${pod_image_name} == ${TEST_IMAGE} ]]
}

@test "Deployment Scale | Scale up the Deployment to 3 replicas" {
  #Scale up the replicas to 3
  $KUBECTL scale --replicas=3 deployment/nginx -n ${NAMESPACE}

  desired_pod=$($KUBECTL get deployment -l run=nginx,test=deployment -n ${NAMESPACE} --no-headers | awk '{print $2}')
  for t in $(seq 1 50)
  do
    desired_pod=$($KUBECTL get deployment -l run=nginx,test=deployment -n ${NAMESPACE} --no-headers | awk '{print $2}')
    if [[ $desired_pod -eq 3 ]]; then
      echo "The deployment desired pods number was changed successfully"
      break
    fi
    sleep 5
  done

  [[ $desired_pod -eq 3 ]]
}

@test "Deployment | Scale down the Deployment from 3 to 1" {
  # Scale down the deployment
  $KUBECTL scale --current-replicas=3 --replicas=1 deployment/nginx -n ${NAMESPACE}

  desired_pod=$($KUBECTL get deployment -l run=nginx,test=deployment -n ${NAMESPACE} --no-headers | awk '{print $2}')

  for t in $(seq 1 50)
  do
    desired_pod=$($KUBECTL get deployment -l run=nginx,test=deployment -n ${NAMESPACE} --no-headers | awk '{print $2}')
    if [[ $desired_pod -eq 1 ]]; then
      echo "The deployment desired pods number was changed successfully"
      break
    fi
  sleep 5
  done
  [[ $desired_pod -eq 1 ]]
}

@test "Deployment | Delete the deployment nginx" {
  # Delete the deployment nginx
  $KUBECTL delete deployments/nginx -n ${NAMESPACE}
  deployment_data=$($KUBECTL get deployment -l run=nginx,test=deployment -n ${NAMESPACE} --no-headers | wc -l | sed 's/^ *//')
  [[ $deployment_data -eq 0 ]]
}
