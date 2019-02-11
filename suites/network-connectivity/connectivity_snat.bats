#!/usr/bin/env bats

# This will load the helpers.
load ../../helpers

@test "SNAT Connectivity | pod to node connectivity" {

   # Deploy pod to ping nodes
   $KUBECTL apply -f suites/network-connectivity/template/busybox_deploy_podnet.yaml --namespace=${NAMESPACE}

   desired_pod=$($KUBECTL get deploy busybox-deploy-snat -n ${NAMESPACE} -ojsonpath={.spec.replicas})

   for t in $(seq 1 100)
   do
       num_podrunning=$($KUBECTL get deploy busybox-deploy-snat -n ${NAMESPACE} -ojsonpath={.status.readyReplicas})

       if [[ $num_podrunning == $desired_pod ]]; then
           echo "The pods are running"
           break
       fi
       sleep 5
   done

   # Get the pod name
   pod_name=$($KUBECTL get pods -lapp=busybox-snat -n ${NAMESPACE} -o jsonpath='{.items[0].metadata.name}')

   # Get node IP address
   node_ip=()

   i=0
   $KUBECTL get nodes --no-headers | { while read line
   do
    node_ip[$i]=`echo $line | cut -d$' ' -f 1`
    i=$((i + 1))
   done


   # Ping nodes from pod
   for ip in ${node_ip[*]}
   do
     echo "Pinging pod: $ip"
     run $KUBECTL exec -it ${pod_name} -n ${NAMESPACE} -- ping -c 5 $ip

     [[ "$status" -eq 0 ]]

   done
 }

}
