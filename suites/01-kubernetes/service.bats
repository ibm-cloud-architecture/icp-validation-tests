#!/usr/bin/env bats
CAPABILITIES=("namespace")

# This will load helpers to be compatible with icp-sert-bats
load ${APP_ROOT}/libs/sert-compat.bash

# Attempt to auto-detect what infrastructure platform
# the ICP environment is running on (azure, gce, vmware, etc)
INF_PLATFORM=$(get_infrastructure_platform)

# Infrastructure platforms that is expected to support kubectl expose deployment --type=LoadBalancer
TESTABLE_PLATFORMS=("azure" "gce" "aws")

# Check if we're on a platform that supports loadbalancers
for p in ${TESTABLE_PLATFORMS[@]}; do
  if [[ ${p} == ${INF_PLATFORM} ]]; then
    RUN_TEST="true"
  fi
done

# TODO Need to support manually enable test for environments where LoadBaancer has custom implementation

# Make sure that the LB Gets created with an IP address
setup() {
  # Only setup the loadbalancer before the first LB Test and if on supported platform
  if [[ "$BATS_TEST_NUMBER" -eq 1 ]]; then
    if [[ "${RUN_TEST}" == "true" ]]; then
      # First create a deployment
      $KUBECTL run nginxlb --labels='run=nginx,test=loadbalancer' --replicas=1 --image-pull-policy=IfNotPresent --image=${TEST_IMAGE} --namespace=${NAMESPACE} --port=80
      # Expose the deployment
      $KUBECTL --namespace=${NAMESPACE} expose deployment nginxlb --port=80 --type=LoadBalancer --labels='run=nginx,test=loadbalancer'
      # Wait for the loadbalancer to be ready
      retries=20
      lb=$($KUBECTL --namespace=${NAMESPACE} get svc -l run=nginx,test=loadbalancer --no-headers | awk '{print $4}')
      while [ "$lb" == "<pending>"  -o "$lb" == "" -o "$retries" -eq 0 ]; do
        retries=$((retries-1))
        sleep 10s
        lb=$($KUBECTL --namespace=${NAMESPACE} get svc -l run=nginx,test=loadbalancer --no-headers | awk '{print $4}')
      done
    fi
    #First create a deployment
    $KUBECTL run nginx --replicas=1 --image-pull-policy=IfNotPresent --image=${TEST_IMAGE} --namespace=${NAMESPACE} --port=80

    num_podrunning=0
    desired_pod=$($KUBECTL get pods -lrun=nginx --namespace=${NAMESPACE} --no-headers | awk '{print $2}' | awk -F '/' '{print $2}')
    for t in $(seq 1 50)
    do
      num_podrunning=$($KUBECTL get pods -lrun=nginx --namespace=${NAMESPACE} --no-headers | awk '{print $2}' | awk -F '/' '{print $1}')
      desired_pod=$($KUBECTL get pods -lrun=nginx --namespace=${NAMESPACE} --no-headers | awk '{print $2}' | awk -F '/' '{print $2}')
      if [[ $num_podrunning == $desired_pod ]]; then
        echo "The pod was running"
        break
      fi
      sleep 5
    done
  fi
}

teardown() {
  # Only tear down the loadbalancer when the last test is completed
  if [[ "$BATS_TEST_NUMBER" -eq ${#BATS_TEST_NAMES[@]} ]]; then
    if [[ "${RUN_TEST}" == "true" ]]; then
      $KUBECTL delete deployment --selector='run=nginx,test=loadbalancer' --ignore-not-found --namespace=${NAMESPACE}
      $KUBECTL delete svc --selector='run=nginx,test=loadbalancer' --ignore-not-found --namespace=${NAMESPACE}
    fi
    #Clean up
    $KUBECTL delete deployment -lrun=nginx --ignore-not-found --namespace=${NAMESPACE}
    for t in $(seq 1 50)
    do
      number=$($KUBECTL get deployment --ignore-not-found --no-headers --namespace=${NAMESPACE} | wc -l | sed 's/^ *//')
      if [[ $number == 0 ]]; then
         echo "The deployment was removed"
         break
      fi
      sleep 5
    done

    $KUBECTL delete service -lrun=nginx --ignore-not-found --namespace=${NAMESPACE}
    for t in $(seq 1 50)
    do
      number=$($KUBECTL get service --ignore-not-found --no-headers --namespace=${NAMESPACE} | wc -l | sed 's/^ *//')
      if [[ $number == 0 ]]; then
         echo "The service was removed"
         break
      fi
      sleep 5
    done
  fi
}

if [[ -s /opt/ibm/cfc/version ]]; then
  in_cluster="true"
else
  in_cluster="false"
fi

@test "Service Create | Create service with ClusterIP" {
  #Create the service with ClusterIP
  $KUBECTL apply -f $sert_bats_workdir/suites/01-kubernetes/template/service/service-clusterIP.yaml --namespace=${NAMESPACE}

  service_number=$($KUBECTL get service -lrun=nginx --namespace=${NAMESPACE} --no-headers | wc -l | sed 's/^ *//')

  [[ $service_number -eq 1 ]]

}

@test "Service Create | Verify service with ClusterIP" {

  if [[ $in_cluster == "false" && $IN_DOCKER == "false" ]]; then
    skip "the test was running outside of ICP cluster, skip the ClusterIP verification"
  fi

  cluster_ip=$($KUBECTL get service nginx --namespace=${NAMESPACE} --no-headers -o jsonpath='{.spec.clusterIP}')

  port=$($KUBECTL get service nginx --namespace=${NAMESPACE} --no-headers -o jsonpath='{.spec.ports[0].port}')

  #Verify the service
  response_code=$(curl --connect-timeout 5 -s -w "%{http_code}" http://$cluster_ip:$port -o /dev/null)

  [[ $response_code == '200' ]]
}

@test "Service Create | Create service with NodePort" {
  #Create the service with NodePort
  $KUBECTL apply -f $sert_bats_workdir/suites/01-kubernetes/template/service/service-nodePort.yaml --namespace=${NAMESPACE}

  service_number=$($KUBECTL get service -lrun=nginx --namespace=${NAMESPACE} --no-headers | wc -l | sed 's/^ *//')

  [[ $service_number -eq 1 ]]
}

@test "Service Create | Verify the service with NodePort" {

  get_master_ip

  node_port=$($KUBECTL get service nginx --namespace=${NAMESPACE} --no-headers -o jsonpath='{.spec.ports[0].nodePort}')

  #Verify the service
  response_code=$(curl --connect-timeout 5 -s -w "%{http_code}" http://$master_ip:$node_port -o /dev/null)

  [[ $response_code == '200' ]]
}

@test "Service Expose | Expose service with ClusterIP" {
  #Clean up the service
  $KUBECTL delete service -lrun=nginx -n ${NAMESPACE} --ignore-not-found

  #Expose the service with ClusterIP
  $KUBECTL expose deployment nginx --port=80 --target-port=80  --name=nginx --type=ClusterIP --namespace=${NAMESPACE}

  service_number=$($KUBECTL get service -lrun=nginx --namespace=${NAMESPACE} --no-headers | wc -l | sed 's/^ *//')

  [[ $service_number -eq 1 ]]
}

@test "Service Expose | Verify the Exposed service with ClusterIP" {

  if [[ $in_cluster == "false" && $IN_DOCKER == "false" ]]; then
    skip "the test was running outside of ICP cluster, skip the ClusterIP verification"
  fi

  cluster_ip=$($KUBECTL get service nginx --namespace=${NAMESPACE} --no-headers -o jsonpath='{.spec.clusterIP}')

  port=$($KUBECTL get service nginx --namespace=${NAMESPACE} --no-headers -o jsonpath='{.spec.ports[0].port}')

  #Verify the service
  response_code=$(curl --connect-timeout 5 -s -w "%{http_code}" http://$cluster_ip:$port -o /dev/null)

  [[ $response_code == '200' ]]
}

@test "Service Expose | Expose service with NodePort" {
  #Clean up the service
  $KUBECTL delete service -lrun=nginx --ignore-not-found -n ${NAMESPACE}

  #Expose the service with NodePort
  $KUBECTL expose deployment nginx --port=80 --target-port=80  --name=nginx --namespace=${NAMESPACE} --type=NodePort

  service_number=$($KUBECTL get service -lrun=nginx --namespace=${NAMESPACE} --no-headers | wc -l | sed 's/^ *//')

  [[ $service_number -eq 1 ]]
}

@test "Service Expose | Verify the Exposed service with NodePort" {

  get_master_ip
  node_port=$($KUBECTL get service nginx --namespace=${NAMESPACE} --no-headers -o jsonpath='{.spec.ports[0].nodePort}')
  #Verify the service
  response_code=$(curl --connect-timeout 5 -s -w "%{http_code}" http://$master_ip:$node_port -o /dev/null)

  [[ $response_code == '200' ]]
}

@test "Service Loadbalance | loadbalancer receives external IP" {
  if [[ "${RUN_TEST}" != "true" ]]; then
      skip "Not in supported cloud, skip loadbalancer validation"
  fi

  lb=$($KUBECTL --namespace=${NAMESPACE} get svc -l run=nginx,test=loadbalancer --no-headers | awk '{print $4}')
  [[ "$lb" != "<pending>" || "$lb" != "" ]]
}

@test "Service Loadbalance | loadbalancer is accessible" {
  if [[ "${RUN_TEST}" != "true" ]]; then
      skip "Not in supported cloud, skip loadbalancer validation"
  fi

  lb=$($KUBECTL --namespace=${NAMESPACE} get svc -l run=nginx,test=loadbalancer --no-headers | awk '{print $4}')
  run curl -I http://$lb
  [[ "$status" = 0 ]]
  [[ "${output}" =~ "200 OK" ]]
}
