#!/usr/bin/env bats

# This will load the helpers.
load ../../helpers

setup() {
  # Only set up this on first test
  if [[ "$BATS_TEST_NUMBER" -eq 1 ]]; then
    # Create a DaemonSet for test
    $KUBECTL apply -f suites/network-connectivity/template/busybox_daemonset.yaml --namespace=${NAMESPACE}

    # Wait until they are all ready
    for t in $(seq 1 50)
    do
      pods_notready=$($KUBECTL get ds busybox-daemonset -n ${NAMESPACE} --no-headers | awk '{ print $2 - $4 }')

      if [[ $pods_notready -eq 0 ]]; then
        # All pods are ready
        break
      fi
      sleep 5
    done

    # Deploy pod on hostNetwork
    $KUBECTL apply -f suites/network-connectivity/template/busybox_deploy_hostnet.yaml --namespace=${NAMESPACE}

    # Wait until readuy
    desired_pod=$($KUBECTL get deploy busybox-deploy -n ${NAMESPACE} -ojsonpath={.spec.replicas})
    for t in $(seq 1 100)
    do
        num_podrunning=$($KUBECTL get deploy busybox-deploy -n ${NAMESPACE} -ojsonpath={.status.readyReplicas})

        if [[ $num_podrunning == $desired_pod ]]; then
            echo "The pods are running"
            break
        fi
        sleep 5
    done
  fi
}

teardown() {
  # Only delete after last test completed
  if [ "$BATS_TEST_NUMBER" -eq ${#BATS_TEST_NAMES[@]} ]; then
    $KUBECTL delete -f suites/network-connectivity/template/busybox_daemonset.yaml --namespace=${NAMESPACE} --ignore-not-found
    $KUBECTL delete -f suites/network-connectivity/template/busybox_deploy_hostnet.yaml --namespace=${NAMESPACE} --ignore-not-found
  fi
}

@test "Network Connectivity | calico test pods running" {

  pods_notready=$($KUBECTL get ds busybox-daemonset -n ${NAMESPACE} --no-headers | awk '{ print $2 - $4 }')

  [[ $pods_notready  -eq 0 ]]


}

@test "Network Connectivity | calico node-to-node mesh test" {



   # Get Pods' IP address
   desired_pod=$($KUBECTL get deploy busybox-deploy -n ${NAMESPACE} -ojsonpath={.spec.replicas})
   max_pod_index=$((desired_pod - 1))

   pod_ip=()
   for i in `seq 0 $max_pod_index`
    do
         pod_ip[$i]=$(kubectl get pods -l app=busybox-ds-ping --namespace=${NAMESPACE} -o jsonpath={.items[$i].status.podIP})
    done


   desired_pod=$($KUBECTL get deploy busybox-deploy -n ${NAMESPACE} -ojsonpath={.spec.replicas})

   for t in $(seq 1 100)
   do
       num_podrunning=$($KUBECTL get deploy busybox-deploy -n ${NAMESPACE} -ojsonpath={.status.readyReplicas})

       if [[ $num_podrunning == $desired_pod ]]; then
           echo "The pods are running"
           break
       fi
       sleep 5
   done

   # Get the pod name
   pod_name=$($KUBECTL get pods -lapp=busybox-hostnet-src -n ${NAMESPACE} -o jsonpath='{.items[0].metadata.name}')


   # Ping pods from master node
   for ip in ${pod_ip[*]}
   do
     echo "Pinging pod: $ip"
     run $KUBECTL exec -it ${pod_name} -n ${NAMESPACE} -- ping -c 5 $ip

     [[ "$status" -eq 0 ]]

   done
}
