#!/usr/bin/env bats
CAPABILITIES=("kubectl" "namespace")

# This will load helpers to be compatible with icp-sert-bats
load ${APP_ROOT}/libs/sert-compat.bash

setup() {
  if [[ $BATS_TEST_NUMBER -eq 1 ]]; then
    # Create a statefulset
    $KUBECTL apply -f $sert_bats_workdir/suites/01-kubernetes/template/statefulset.yaml --namespace=${NAMESPACE}
    running_pod=0
    desired_pod=$($KUBECTL get sts -l app=test-sts --namespace=${NAMESPACE} --no-headers | awk '{print $2}')
    for t in $(seq 1 50)
    do
        running_pod=$($KUBECTL get sts -l app=test-sts --namespace=${NAMESPACE} --no-headers | awk '{print $3}')
        if [[ $running_pod -eq $desired_pod ]]; then
            echo "The statefulset has created successful."
            break
        fi
        sleep 5
    done
  fi
}

teardown() {
  if [[ "$BATS_TEST_NUMBER" -eq ${#BATS_TEST_NAMES[@]} ]]; then
    # Clean up
    $KUBECTL delete -f $sert_bats_workdir/suites/01-kubernetes/template/statefulset.yaml --namespace=${NAMESPACE} --ignore-not-found --force --grace-period=0
  fi
}

@test "StatefulSet Create | Create a statefulset" {
    statefulset_data=$($KUBECTL get sts test-sts --namespace=${NAMESPACE} --no-headers | wc -l | sed 's/^ *//')
    [[ $statefulset_data -ne 0 ]]
}

@test "StatefulSet Create | Verify the statefulset create successfully" {
    # Check the statefulset create successfully
    running_pod=$($KUBECTL get sts test-sts --namespace=${NAMESPACE} --no-headers | awk '{print $3}')
    desired_pod=$($KUBECTL get sts test-sts --namespace=${NAMESPACE} --no-headers | awk '{print $2}')
    [[ $running_pod -eq $desired_pod ]]
}

@test "StatefulSet Create | Verify the order is correct during the create" {
    age1=$($KUBECTL get pods test-sts-0 --namespace=${NAMESPACE} --no-headers | awk '{print $5}')
    age2=$($KUBECTL get pods test-sts-1 --namespace=${NAMESPACE} --no-headers | awk '{print $5}')
    age3=$($KUBECTL get pods test-sts-2 --namespace=${NAMESPACE} --no-headers | awk '{print $5}')

    [ "$age2" > "$age3" ]
    [ "$age1" > "$age2" ]
}

@test "Statefulset Scale | Verify scaling up the statefulset" {
    # Check the statefulset scale successfully
    num_available=0
    $KUBECTL scale sts test-sts --replicas=5 --namespace=${NAMESPACE}
    for t in $(seq 1 50)
    do
        num_available=$($KUBECTL get sts test-sts --namespace=${NAMESPACE} --no-headers | awk '{print $3}')
        if [[ $num_available -eq 5 ]]; then
            echo "The statefulset has scaled out successfully."
            break
        fi
        sleep 5
    done
    [[ $num_available -eq 5 ]]
}

@test "Statefulset Scale | Verify scaling down the statefulset" {
    # Check the statefulset scale successfully
    num_available=0
    $KUBECTL patch sts test-sts -p '{"spec":{"replicas":3}}' --namespace=${NAMESPACE}
    for t in $(seq 1 50)
    do
        num_available=$($KUBECTL get sts test-sts --namespace=${NAMESPACE} --no-headers | awk '{print $3}')
        if [[ $num_available -eq 3 ]]; then
            echo "The statefulset has scaled out successfully."
            break
        fi
        sleep 5
    done
    [[ $num_available -eq 3 ]]
}

@test "Statefulset Scale | Verify rolling update the statefulset" {
   pod_image=""

   expect_image="nginx:1.15.8-alpine"

   # Check the statefulset rolling update successfully or not
   $KUBECTL patch statefulset test-sts -p '{"spec":{"updateStrategy":{"type":"RollingUpdate"}}}' --namespace=${NAMESPACE}

   $KUBECTL patch statefulset test-sts --namespace=${NAMESPACE} --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/image", "value":"nginx:1.15.8-alpine"}]'

   running_pod_num=$($KUBECTL get sts test-sts --namespace=${NAMESPACE} --no-headers | awk '{print $3}')
   let running_pod_num-=1

   for t in $(seq 1 50)
   do
        num_roll=0
        for p in $(seq 0 $running_pod_num)
        do
            pod_image=$($KUBECTL get po test-sts-$p --template '{{range $i, $c := .spec.containers}}{{$c.image}}{{end}}' --namespace=${NAMESPACE})

            if [[ $pod_image == $expect_image ]]; then
            echo "The statefulset has updated successfully for pod test-sts-$p "
            let num_roll+=1
            fi
            sleep 1
        done

        if [[ num_roll -eq 3  ]]; then
        break
        fi
        sleep 5
   done

   run echo $pod_image
   [ $output = $expect_image ]
}

@test "Statefulset Delete | Verify deleting the statefulset" {

   # Delete the statefulset
   $KUBECTL delete statefulset test-sts --namespace=${NAMESPACE} --ignore-not-found

   statefulset_data=$($KUBECTL get sts test-sts --namespace=${NAMESPACE} --no-headers | wc -l | sed 's/^ *//')
   [[ $statefulset_data -eq 0 ]]
}
