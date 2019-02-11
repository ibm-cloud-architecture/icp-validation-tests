#!/usr/bin/env bats

# This will load the helpers.
load ../../helpers


teardown() {
  # Only delete after last test completed
  if [ "$BATS_TEST_NUMBER" -eq ${#BATS_TEST_NAMES[@]} ]; then
    $KUBECTL delete -f suites/network-connectivity/template/pod1.yaml --namespace=${NAMESPACE} --ignore-not-found
    $KUBECTL delete -f suites/network-connectivity/template/pod2.yaml --namespace=${NAMESPACE} --ignore-not-found
  fi
}


@test "Network Connectivity | Check pod to pod traffic" {

   # create pod1
   $KUBECTL create -f ./suites/network-connectivity/template/pod1.yaml -n ${NAMESPACE}

   num_podrunning=0
   desired_pod=$($KUBECTL get deploy pod1 -n ${NAMESPACE} -ojsonpath={.spec.replicas})
   for t in $(seq 1 50)
   do
       num_podrunning=$($KUBECTL get deploy pod1 -n ${NAMESPACE} -ojsonpath={.status.readyReplicas})
       if [[ $num_podrunning == $desired_pod ]]; then
           echo "The deployment pod1 was running"
           break
       fi
       sleep 5
   done

   # create pod2
   $KUBECTL create -f ./suites/network-connectivity/template/pod2.yaml -n ${NAMESPACE}

   num_podrunning=0
   desired_pod=$($KUBECTL get deploy pod2 -n ${NAMESPACE} -ojsonpath={.spec.replicas})
   for t in $(seq 1 50)
   do
       num_podrunning=$($KUBECTL get deploy pod2 -n ${NAMESPACE} -ojsonpath={.status.readyReplicas})
       if [[ $num_podrunning == $desired_pod ]]; then
           echo "The deployment pod2 was running"
           break
       fi
       sleep 5
   done

   # Get the pod1 name and pod2 ip address
   pod2_ip=$($KUBECTL get pods -lapp=pingdst -n ${NAMESPACE} -o jsonpath='{.items[0].status.podIP}')
   pod1_name=$($KUBECTL get pods -lapp=pingsrc -n ${NAMESPACE} -o jsonpath='{.items[0].metadata.name}')
   echo pod2_ip $pod2_ip
   echo pod1_name $pod1_name

   run $KUBECTL exec -it ${pod1_name} -n ${NAMESPACE} -- ping -c5 ${pod2_ip}
   echo $output
   [[ "$status" -eq 0 ]]
}
