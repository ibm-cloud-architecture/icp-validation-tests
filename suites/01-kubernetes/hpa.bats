#!/usr/bin/env bats
CAPABILITIES=("kubectl" "namespace")

# This will load helpers to be compatible with icp-sert-bats
load ${APP_ROOT}/libs/sert-compat.bash
load ${APP_ROOT}/libs/sequential-helpers.bash

applicable() {
  # Determine whether these tests are applicable in this environment
  if [[ ${API_VERSIONS[@]} =~ "metrics.k8s.io" ]]; then
    # Metrics API exists in this environment
    return 0
  else
    # We don't support metrics in this environment, so will not apply
    return 1
  fi
}
create_environment() {

    # Create the sample application used for test
    $KUBECTL run php-apache --image="php:7.3-apache" --requests=cpu=200m --expose --port=80 --namespace=${NAMESPACE}
    # Waiting for pod startup

    num_podrunning=0
    desired_pod=$($KUBECTL get pods -lrun=php-apache --namespace=${NAMESPACE} --no-headers | awk '{print $2}' | awk -F '/' '{print $2}')
    for t in $(seq 1 50)
    do
        num_podrunning=$($KUBECTL get pods -lrun=php-apache --namespace=${NAMESPACE} --no-headers | awk '{print $2}' | awk -F '/' '{print $1}')
        desired_pod=$($KUBECTL get pods -lrun=php-apache --namespace=${NAMESPACE} --no-headers | awk '{print $2}' | awk -F '/' '{print $2}')
        if [[ $num_podrunning == $desired_pod ]]; then
            echo "The pod was running"
            break
        fi
        sleep 5
    done
}

destroy_environment() {
  # Clean up
  if [[ "$BATS_TEST_NUMBER" -eq 7 ]]; then
    $KUBECTL delete deployment php-apache php-apache-load --ignore-not-found --namespace=${NAMESPACE} --force --grace-period=0
    for t in $(seq 1 50)
    do
      number=$($KUBECTL get deployment php-apache --ignore-not-found --no-headers | wc -l | sed 's/^ *//')
      if [[ $number == 0 ]]; then
        echo "The deployment php-apache was removed"
        break
      fi
      sleep 5
    done
    for t in $(seq 1 50)
    do
      number=$($KUBECTL get deployment php-apache-load --ignore-not-found --no-headers | wc -l | sed 's/^ *//')
      if [[ $number == 0 ]]; then
        echo "The deployment php-apache-load was removed"
        break
      fi
      sleep 5
    done

    $KUBECTL delete hpa php-apache --ignore-not-found --namespace=${NAMESPACE} --force --grace-period=0
    for t in $(seq 1 50)
    do
      number=$($KUBECTL get hpa php-apache --ignore-not-found --no-headers | wc -l | sed 's/^ *//')
      if [[ $number == 0 ]]; then
        echo "The hpa was removed"
        break
      fi
      sleep 5
    done
  fi

  if [[ "$BATS_TEST_NUMBER" -eq ${#BATS_TEST_NAMES[@]} ]]; then
    $KUBECTL delete -f $sert_bats_workdir/suites/01-kubernetes/template/hpa/hpa-customer-policy.yaml -n ${NAMESPACE}
  fi
}

@test "HPA Policy Load Increase| Create HPA policy" {
  # Create HPA policy
  $KUBECTL autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10 --namespace=${NAMESPACE}

  # Check HPA policy
  hpa_policy_number=$($KUBECTL get hpa --namespace=${NAMESPACE} --no-headers | wc -l | sed 's/^ *//')

  [[ $hpa_policy_number -eq 1 ]]
}

@test "HPA Policy Load Increase| Check HPA policy status to make sure metric collected" {

  #Check HPA policy status
  current_cpuUT=$($KUBECTL get hpa --namespace=${NAMESPACE} php-apache -o jsonpath={.status.currentCPUUtilizationPercentage})
  for t in $(seq 1 50)
  do
    current_cpuUT=$($KUBECTL get hpa --namespace=${NAMESPACE} php-apache -o jsonpath={.status.currentCPUUtilizationPercentage})
    if [[ X$current_cpuUT != X ]]; then
      echo "The CPU UT was: $current_cpuUT"
      break
    fi
  sleep 5
  done

  [[ X$current_cpuUT != X ]]

}

@test "HPA Policy load Increase| Increase load and check the current CPU load" {

  #Get the pod IP
  pod_ip=$($KUBECTL get pods -lrun=php-apache --namespace=${NAMESPACE} -o jsonpath='{.items[0].status.podIP}')

  $KUBECTL run php-apache-load --image=busybox --namespace=${NAMESPACE} --command -- /bin/sh -c "while true; do wget -q -O- http://${pod_ip}; done"

  #Checking the current cpu load
  for t in $(seq 1 50)
  do
    current_cpuUT=$($KUBECTL get hpa --namespace=${NAMESPACE} php-apache -o jsonpath={.status.currentCPUUtilizationPercentage})
    if [[ X$current_cpuUT != X || X$current_cpuUT != X0 ]]; then
      echo "The CPU UT was: $current_cpuUT"
      break
    fi
    sleep 5
  done

  current_cpuUT=$($KUBECTL get hpa --namespace=${NAMESPACE} php-apache -o jsonpath={.status.currentCPUUtilizationPercentage})
  [[ X$current_cpuUT != X || X$current_cpuUT != X0 ]]

}

@test "HPA Policy load Increase| Check the applications were scale up after the cpu load increase" {

  #Compare the current cpu UT with target cpu
  target_cpu=$($KUBECTL get hpa -n ${NAMESPACE} php-apache -o jsonpath={.spec.targetCPUUtilizationPercentage})

  for t in $(seq 1 50)
  do
    current_cpu=$($KUBECTL get hpa -n ${NAMESPACE} php-apache -o jsonpath={.status.currentCPUUtilizationPercentage})
    if [[ $current_cpu -lt $target_cpu ]]; then
      echo "The current cpu ut was large than target cpu"
      break
    fi
    sleep 5
  done

  #Check if the applications were scale up
  for t in $(seq 1 50)
  do
    replicas_num=$($KUBECTL get deployment -n ${NAMESPACE} php-apache -o jsonpath={.status.replicas})
    if [[ $replicas_num != 1 ]]; then
      echo "the applications was scale up"
      break
    fi
    sleep 5
  done

  [[ $replicas_num != 1 ]]
}

@test "HPA Policy load Decrease| Check the applications were scale down after the cpu load decrease" {

  current_replicas=$($KUBECTL get deployment -n ${NAMESPACE} php-apache -o jsonpath={.status.replicas})

  $KUBECTL delete deployment -l run=php-apache-load -n ${NAMESPACE}
  #Check if the applications were scale down
  for t in $(seq 1 20)
  do
    replicas_num=$($KUBECTL get deployment -n ${NAMESPACE} php-apache -o jsonpath={.status.replicas})
    if [[ $replicas_num != $current_replicas ]]; then
      echo "the applications was scale down"
      break
    fi
    sleep 20
  done

  [[ $replicas_num != $current_replicas ]]
}

@test "HPA Policy Update | Update the HPA policy" {

  #Get HPA policy max replicas
  max_replicas=$($KUBECTL get hpa --namespace=${NAMESPACE} php-apache -o jsonpath={.spec.maxReplicas})

  #Update HPA policy max replicas
  $KUBECTL apply -f $sert_bats_workdir/suites/01-kubernetes/template/hpa/hpa-policy.yaml --namespace=${NAMESPACE}

  #Get The current HPA policy max replicas
  new_replicas=$($KUBECTL get hpa --namespace=${NAMESPACE} php-apache -o jsonpath={.spec.maxReplicas})

  [[ $max_replicas != $new_replicas ]]
}

@test "HPA Customer Metrics | Check the api group" {

  _api_version=$($KUBECTL api-versions |grep "autoscaling/v2beta1"| wc -l | sed 's/^ *//')

  [[ $_api_version -eq 1 ]]
}

@test "HPA Customer Metrics | Check the customer metrics adapter pod" {

  _pods_status=$($KUBECTL get po -n kube-system -l app=custom-metrics-adapter --no-headers | grep Running | wc -l | sed 's/^ *//')

  [[ $_pods_status -eq 1 ]]
}

@test "HPA Customer Metrics | Check the metrics server pod" {

  _pods_status=$($KUBECTL get po -n kube-system -l k8s-app=metrics-server --no-headers | grep Running | wc -l | sed 's/^ *//')

  [[ $_pods_status -eq 1 ]]
}

@test "HPA Customer Metrics | Check the default custom metrics provided by prometheus" {
  $KUBECTL get --raw "/apis/custom.metrics.k8s.io/v1beta1" | jq .  |grep "pods/"
}

@test "HPA Customer Metrics | Deploying an application with a HPA Customer metrics policy" {
  _target_metrics=$($KUBECTL get hpa podinfo -n ${NAMESPACE} -o yaml | grep autoscaling.alpha.kubernetes.io/metrics | awk -F'"' '{print $(NF-1)}')
  [[ $_target_metrics != "" ]]
}

@test "HPA Customer Metrics | Check the HPA Customer metrics policy currentAverageValue" {
  _current_metrics=$($KUBECTL get hpa podinfo -n ${NAMESPACE} -o yaml | grep autoscaling.alpha.kubernetes.io/current-metrics | awk -F'"' '{print $(NF-1)}')
  for t in $(seq 1 50)
  do
    _current_metrics=$($KUBECTL get hpa podinfo -n ${NAMESPACE} -o yaml | grep autoscaling.alpha.kubernetes.io/current-metrics | awk -F'"' '{print $(NF-1)}')
    if [[ $_current_metrics != "" ]]; then
      echo "The current average value $_current_metrics"
      break
    fi
    sleep 5
  done
  [[ $_current_metrics != "" ]]
}
