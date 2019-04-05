#!/usr/bin/env bats
CAPABILITIES=("kubectl" "namespace")

# This will load helpers to be compatible with icp-sert-bats
load ${APP_ROOT}/libs/sert-compat.bash

get_master_ip
get_router_https_port
get_auth_token

teardown () {
  if [[ "$BATS_TEST_NUMBER" -eq ${#BATS_TEST_NAMES[@]} ]]; then
    # Clean up
    $KUBECTL delete -f $sert_bats_workdir/suites/01-kubernetes/template/management-ingress.yaml --namespace=${NAMESPACE} --ignore-not-found --force --grace-period=0
  fi
}

@test "management-ingress | Check the custom app api by ingress " {

  #create custom app
  $KUBECTL apply -f $sert_bats_workdir/suites/01-kubernetes/template/management-ingress.yaml --namespace=${NAMESPACE}

  # Waiting for pod startup

  num_podrunning=0
  desired_pod=$($KUBECTL get pods -lapp=podinfo --namespace=${NAMESPACE} --no-headers | awk '{print $2}' | awk -F '/' '{print $2}')
  for t in $(seq 1 50)
  do
    num_podrunning=$($KUBECTL get pods -lapp=podinfo --namespace=${NAMESPACE} --no-headers | awk '{print $2}' | awk -F '/' '{print $1}')
    desired_pod=$($KUBECTL get pods -lapp=podinfo --namespace=${NAMESPACE} --no-headers | awk '{print $2}' | awk -F '/' '{print $2}')
    if [[ $num_podrunning == $desired_pod ]]; then
      echo "The pod was running"
      break
    fi
      sleep 5
  done

  for t in $(seq 1 50)
  do
    ing_address=$($KUBECTL get ing podinfo -n ${NAMESPACE}  --no-headers -o jsonpath={.status.loadBalancer.ingress[0].ip})
    if [[ "x$ing_address" != "x" ]]; then
      echo "ingress ip is ok now"
      break
    fi
    sleep 5
  done
  request_code=$(curl --connect-timeout 5 -s -w "%{http_code}" -k -H "Authorization: Bearer $auth_token" https://$master_ip:$router_https_port/podinfo/version -o /dev/null)

  [[ $request_code == '200' ]]
}

@test "management-ingress | Check the unified-router nodedetails api by ingress" {
  # Check the unified-router nodedetails api by ingress
  request_code=$(curl --connect-timeout 5 -s -w "%{http_code}" -k -H "Authorization: Bearer $auth_token" https://$master_ip:$router_https_port/unified-router/api/v1/nodedetail -o /dev/null)

  [[ $request_code == '200' ]]
}
