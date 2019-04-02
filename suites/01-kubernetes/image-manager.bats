#!/usr/bin/env bats
CAPABILITIES=("selfsigned_registry" "namespace")

# This will load helpers to be compatible with icp-sert-bats
load ${APP_ROOT}/libs/sert-compat.bash

setup() {
  if [[ $BATS_TEST_NUMBER -eq 2 ]]; then
    if [[ $(uname -s) == 'Darwin' ]]; then
      skip "Did not support this case on MacOS so far"
    else
      #First prepare the docker cert
      if [[ $IN_DOCKER == "false" ]]; then
        if [[ ! -s /etc/docker/certs.d/$CLUSTERNAME.icp:8500 ]]; then
          sudo mkdir -p /etc/docker/certs.d/$CLUSTERNAME.icp:8500/
          # Start the container which used to copy the docker cert from one of worker node
          $KUBECTL apply -f $sert_bats_workdir/suites/01-kubernetes/template/image-manager.yaml -n ${NAMESPACE}
          # wait for pod startup, and then copy the docker cert from the container
          num_podrunning=0
          desired_pod=$($KUBECTL get pods -lapp=http-svc --namespace=${NAMESPACE} --no-headers | awk '{print $2}' | awk -F '/' '{print $2}')
          for t in $(seq 1 50)
          do
              num_podrunning=$($KUBECTL get pods -lapp=http-svc --namespace=${NAMESPACE} --no-headers | awk '{print $2}' | awk -F '/' '{print $1}')
              desired_pod=$($KUBECTL get pods -lapp=http-svc --namespace=${NAMESPACE} --no-headers | awk '{print $2}' | awk -F '/' '{print $2}')
              if [[ $num_podrunning == $desired_pod ]]; then
                  echo "The pod was running"
                  break
              fi
              sleep 5
          done

          _pod_name=$($KUBECTL get pods -lapp=http-svc --namespace=${NAMESPACE} --no-headers | awk '{print $1}')
          #Copy the docker cert
          $KUBECTL -n ${NAMESPACE} exec $_pod_name cat /docker-cert/certs.d/$CLUSTERNAME.icp:8500/ca.crt | sudo tee -a /etc/docker/certs.d/$CLUSTERNAME.icp:8500/ca.crt
        fi
      fi
    fi
  fi
}

teardown() {
  if [[ "$BATS_TEST_NUMBER" -eq ${#BATS_TEST_NAMES[@]} ]]; then
    $KUBECTL delete -f $sert_bats_workdir/suites/01-kubernetes/template/image-manager.yaml -n ${NAMESPACE} --force --grace-period=0 --ignore-not-found
  fi
}

@test "Image Manager | Make sure the Image Manager was started on each of master node" {
  get_num_master
  # Get the pod number
  pod_number=$($KUBECTL get pods -lapp=image-manager -n kube-system --no-headers | wc -l | sed 's/^ *//')

  [[ $pod_number == $node_number ]]
}


@test "Image Manager | Login to Private registry" {
  get_credentials
  # Docker Login to private registry
  docker login $CLUSTERNAME.icp:8500 -u $username -p $password
  [[ $? -eq 0 ]]
}

@test "Image Manager | Push the Image to Private registry" {
  if [[ $(uname -s) == 'Darwin' ]]; then
    skip "Did not support this case on MacOS so far"
  fi
  # Docker Retag Image
  docker pull alpine:latest
  _image_id=$(docker images|grep alpine|head -n 1|awk '{print $3}')
  # retag image
  docker tag $_image_id $CLUSTERNAME.icp:8500/${NAMESPACE}/alpine:latest

  # Push the image to private registry
  docker push $CLUSTERNAME.icp:8500/${NAMESPACE}/alpine:latest

  [[ $? -eq 0 ]]
}

@test "Image Manager | Pull the Image from Private registry" {
  if [[ $(uname -s) == 'Darwin' ]]; then
    skip "Did not support this case on MacOS so far"
  fi
  # Pull Image from private registry
  docker pull $CLUSTERNAME.icp:8500/${NAMESPACE}/alpine:latest

  [[ $? -eq 0 ]]
}
