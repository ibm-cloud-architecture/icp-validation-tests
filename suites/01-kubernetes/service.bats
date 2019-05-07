#!/usr/bin/env bats
CAPABILITIES=("kubectl" "namespace")

# This will load helpers to be compatible with icp-sert-bats
load ${APP_ROOT}/libs/sequential-helpers.bash

# Load aditional helpers
load ${APP_ROOT}/libs/wait-helper.bash

# Attempt to auto-detect what infrastructure platform
# the ICP environment is running on (azure, gce, vmware, etc)
INF_PLATFORM=$(get_infrastructure_platform)

# Infrastructure platforms that is expected to support kubectl expose deployment --type=LoadBalancer
LB_SVC_PLATFORMS=("azure" "gce" "aws")

# Check if we're on a platform that supports loadbalancers
for p in ${LB_SVC_PLATFORMS[@]}; do
  if [[ ${p} == ${INF_PLATFORM} ]]; then
    RUN_LB_TEST="true"
  fi
done

# TODO Need to support manually enable test for environments where LoadBaancer has custom implementation

create_environment() {
  # Create the deployment that the various connectivity tests will be run against
  kube run httpserver --labels='run=http,test=service,type=server' --replicas=1 --image-pull-policy=IfNotPresent --image=${HTTP_IMAGE_SMALL} --port=80

  # Create the baseline service with cluster IP
  kube expose deployment httpserver --name="httpserver" --port=80 --labels='run=http,test=service,type=clusterip' --selector='run=http,test=service,type=server'

  # If we are running loadbalancer tests, we should create the loadbalancer now
  if [[ "${RUN_LB_TEST}" == "true" ]]; then
    kube expose service httpserver --name="loadbalancertest" --port=80 --type=LoadBalancer --selector='run=http,test=service,type=server' --labels='run=http,test=service,type=loadbalancer'
  fi
}

environment_ready() {
  # We're ready to perform tests when the http server is ready
  kube get pods -l run=http,test=service | grep Running
}

destroy_environment() {
  # Cleanup the environment
  kube delete svc -l run=http,test=service
  kube delete deployment -l run=http,test=service
}

@test "Service Create | Create service with ClusterIP" {

  # Ensure clusterip created, checking for the line "80/TCP" which indicates that it's exposed
  assert_or_bail 'wait_for -c "kube get svc -l run=http,test=service,type=clusterip" -o "80/TCP"'
}

@test "Service Create | Verify connectivity to ClusterIP" {

  # Get the ClusterIP
  clusterip=$(kube get svc -l run=http,test=service,type=clusterip -o jsonpath='{.items[0].spec.clusterIP}')


  # Create a pod to test connectivity using the toolbox image
  kube run httpclient --labels='run=http,test=service,type=client' --replicas=1 --image=${TOOLBOX_IMAGE_WGET} -- sleep 10m
  assert_and_continue 'wait_for -t 120 -c "kube get pods -l run=http,test=service,type=client" -o "Running"'

  # Attempt to wget the serviceip. wget will exit 0 on success, else > 0, which will be returned by kubectl
  run kube exec -it $(kube get pods -l run=http,test=service,type=client -o jsonpath='{.items[0].metadata.name}') -- wget ${clusterip}

  # Validate that wget returned success
  assert_and_continue '[[ $status -eq 0 ]]'
}

@test "Service Create | Create service with NodePort" {

  # if [[ "${NODEPORT}" == "disabled" ]]; then
  #   skip "NodePort not enabled in this environment"
  # fi

  # Generally we won't do this in environments that support external loadbalancer
  if [[ "${RUN_LB_TEST}" == "true" ]]; then
    skip "Environment supports loadbalancer, will test that instead"
  fi

  # Expose nodeport
  kube expose deployment httpserver --selector='run=http,test=service,type=server' -l run=http,test=service,type=nodeport --type="NodePort" --port=80 --name="httpservernodeport"

  # Validate that a nodeport has been assigned
  nodeport=$(kube get svc -l run=http,test=service,type=nodeport -o jsonpath='{.items[0].spec.ports[0].nodePort}')

  assert_and_continue "[[ $nodeport -gt 0 ]]"

}

@test "Service Create | Verify the service with NodePort" {

  if [[ "${NODEPORT}" == "disabled" ]]; then
    skip "NodePort not enabled in this environment"
  fi

  # Generally we won't do this in environments that support external loadbalancer
  if [[ "${RUN_LB_TEST}" == "true" ]]; then
    skip "Environment supports loadbalancer, will test that instead"
  fi

  # Get the nodeport
  nodeport=$(kube get svc -l run=http,test=service,type=nodeport -o jsonpath='{.items[0].spec.ports[0].nodePort}')

  # Attempt to connect to it
  response_code=$(curl --connect-timeout 5 -s -w "%{http_code}" http://$PROXY_ADDRESS:$nodeport -o /dev/null)

  assert_and_continue '[[ $response_code -eq 200 ]]'

}

@test "Service Loadbalance | loadbalancer receives external IP" {
  if [[ "${RUN_LB_TEST}" != "true" ]]; then
      skip "Not in supported cloud, skip loadbalancer validation"
  fi

  lb=$(kube get svc -l run=http,test=service,type=loadbalancer --no-headers | awk '{print $4}')
  [[ "$lb" != "<pending>" || "$lb" != "" ]]
}

@test "Service Loadbalance | loadbalancer is accessible" {
  if [[ "${RUN_LB_TEST}" != "true" ]]; then
      skip "Not in supported cloud, skip loadbalancer validation"
  fi

  lb=$(kube get svc -l run=http,test=service,type=loadbalancer --no-headers | awk '{print $4}')
  run curl -I http://$lb
  [[ "$status" = 0 ]]
  [[ "${output}" =~ "200 OK" ]]
}
