#!/usr/bin/env bats

# This will load the helpers.
load ../../helpers

@test "management-ingress | Check the custom app api by ingress " {
    #create custom app
    $KUBECTL apply -f suites/management-ingress/sample --namespace=${NAMESPACE}

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
    token_id=$($KUBECTL config view -o jsonpath='{.users[?(@.name == "admin")].user.token}')
    request_code=$(curl --connect-timeout 5 -s -w "%{http_code}" -k -H "Authorization: Bearer $token_id" https://$ACCESS_IP:$ROUTER_HTTPS_PORT/podinfo/version -o /dev/null)

    [[ $request_code == '200' ]]

}
