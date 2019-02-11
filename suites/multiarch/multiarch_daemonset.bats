#!/usr/bin/env bats

MULTIARCH_IMAGE="busybox"

function deploy() {
  if [[ "$1" == "all" ]]; then
    arch="-all"
    local arch_selector=""
  else
    arch="-${1}"
    local arch_selector="beta.kubernetes.io/arch: \"$1\""
  fi
  cat <<EOF | $KUBECTL apply --namespace=${NAMESPACE} -f -
apiVersion: apps/v1beta2 # for versions before 1.8.0 use apps/v1beta1
kind: DaemonSet
metadata:
  name: multiarch-test${arch}
  labels:
    name: multiarch-test${arch}
spec:
  selector:
    matchLabels:
      name: multiarch-test${arch}
  template:
    metadata:
      labels:
        name: multiarch-test${arch}
    spec:
      nodeSelector:
        node-role.kubernetes.io/worker: "true"
        ${arch_selector}
      containers:
      - name: daemonset-test
        image: ${MULTIARCH_IMAGE}
        command: ["/bin/sh"]
        args: ["-c", "echo container_started... ; while true; do sleep 10;done"]
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 200Mi
EOF
}

function wait_and_getpods_running() {
  num_available=0
  local _desired=$1
  local _arch=$2

  for t in $(seq 1 50)
  do
      num_available=$($KUBECTL get pods  -l name=multiarch-test-${_arch} --namespace=${NAMESPACE} --no-headers | grep Running | wc -l)
      if [[ $num_available -eq $_desired ]]; then
          break
      fi
      sleep 5
  done
  echo ${num_available}
}

function waitfor_containersrunning() {
  local _arch=$1
  local _desired=$2

  for t in $(seq 1 50)
  do
      num_available=$($KUBECTL get daemonset -l name=multiarch-test-${_arch} --namespace=${NAMESPACE} --no-headers | awk '{print $4}')
      if [[ $num_available -eq $_desired ]]; then
          break
      fi
      sleep 5
  done
}
# AMD64 Test
@test "Multiarch | Create daemonset only on amd64 workers" {

    _arch="amd64"
    workers=( $($KUBECTL get nodes --no-headers --show-labels -l node-role.kubernetes.io/worker=true,beta.kubernetes.io/arch=${_arch} | awk '{ print $1 }') )
    # Skip if we don't have amd64 workers in the cluster
    if [[ "${#workers[@]}" -eq  0 ]]; then
      skip "No ${_arch} workers found in cluster"
    fi

    # Deploy daemonset
    deploy $_arch

    # Validate that desired pods = number of arch workers
    desired=$($KUBECTL get daemonset -l name=multiarch-test-${_arch} --namespace=${NAMESPACE} --no-headers | awk '{ print $2 }')
    [[ ${#workers[@]} -eq $desired ]]
}

@test "Multiarch | amd64 pods started successfully" {

    _arch="amd64"
    workers=( $($KUBECTL get nodes --no-headers --show-labels -l node-role.kubernetes.io/worker=true,beta.kubernetes.io/arch=${_arch} | awk '{ print $1 }') )
    # Skip if we don't have amd64 workers in the cluster
    if [[ "${#workers[@]}" -eq  0 ]]; then
      skip "No ${_arch} workers found in cluster"
    fi

    num_available=$(wait_and_getpods_running ${#workers[@]} ${_arch})

    # Check the pod Running number
    [[ $num_available -eq ${#workers[@]} ]]
}

@test "Multiarch | amd64 pods outputting correctly" {

    _arch="amd64"
    workers=( $($KUBECTL get nodes --no-headers --show-labels -l node-role.kubernetes.io/worker=true,beta.kubernetes.io/arch=${_arch} | awk '{ print $1 }') )
    # Skip if we don't have amd64 workers in the cluster
    if [[ "${#workers[@]}" -eq  0 ]]; then
      skip "No ${_arch} workers found in cluster"
    fi

    # Attempt to wait for containers to be ready
    local _desired="${#workers[@]}"
    waitfor_containersrunning $_arch $_desired

    output_correctly=$($KUBECTL --namespace=${NAMESPACE}  logs -l name=multiarch-test-${_arch} | grep container_started | wc -l )

    # Cleanup
    $KUBECTL --namespace=${NAMESPACE} delete daemonset -l name=multiarch-test-${_arch}

    # Check all containers outputted as expected
    [[ $output_correctly -eq ${#workers[@]} ]]
}


# ppc64le tests
@test "Multiarch | Create daemonset only on ppc64le workers" {

    _arch="ppc64le"
    workers=( $($KUBECTL get nodes --no-headers --show-labels -l node-role.kubernetes.io/worker=true,beta.kubernetes.io/arch=${_arch} | awk '{ print $1 }') )
    # Skip if we don't have amd64 workers in the cluster
    if [[ "${#workers[@]}" -eq  0 ]]; then
      skip "No ${_arch} workers found in cluster"
    fi

    # Deploy daemonset
    deploy $_arch

    # Validate that desired pods = number of arch workers
    desired=$($KUBECTL get daemonset -l name=multiarch-test-${_arch} --namespace=${NAMESPACE} --no-headers | awk '{ print $2 }')
    [[ ${#workers[@]} -eq $desired ]]
}

@test "Multiarch | ppc64le pods started successfully" {

    _arch="ppc64le"
    workers=( $($KUBECTL get nodes --no-headers --show-labels -l node-role.kubernetes.io/worker=true,beta.kubernetes.io/arch=${_arch} | awk '{ print $1 }') )
    # Skip if we don't have amd64 workers in the cluster
    if [[ "${#workers[@]}" -eq  0 ]]; then
      skip "No ${_arch} workers found in cluster"
    fi

    num_available=$(wait_and_getpods_running ${#workers[@]} ${_arch})

    # Check the pod Running number
    [[ $num_available -eq ${#workers[@]} ]]
}

@test "Multiarch | ppc64le pods outputting correctly" {

    _arch="ppc64le"
    workers=( $($KUBECTL get nodes --no-headers --show-labels -l node-role.kubernetes.io/worker=true,beta.kubernetes.io/arch=${_arch} | awk '{ print $1 }') )
    # Skip if we don't have amd64 workers in the cluster
    if [[ "${#workers[@]}" -eq  0 ]]; then
      skip "No ${_arch} workers found in cluster"
    fi

    # Attempt to wait for containers to be ready
    local _desired="${#workers[@]}"
    waitfor_containersrunning $_arch $_desired
    output_correctly=$($KUBECTL --namespace=${NAMESPACE}  logs -l name=multiarch-test-${_arch} | grep container_started | wc -l )

    # Cleanup
    $KUBECTL --namespace=${NAMESPACE} delete daemonset -l name=multiarch-test-${_arch}

    # Check all containers outputted as expected
    [[ $output_correctly -eq ${#workers[@]} ]]
}

# s390x tests
@test "Multiarch | Create daemonset only on s390x workers" {

    _arch="s390x"
    workers=( $($KUBECTL get nodes --no-headers --show-labels -l node-role.kubernetes.io/worker=true,beta.kubernetes.io/arch=${_arch} | awk '{ print $1 }') )
    # Skip if we don't have amd64 workers in the cluster
    if [[ "${#workers[@]}" -eq  0 ]]; then
      skip "No ${_arch} workers found in cluster"
    fi

    # Deploy daemonset
    deploy $_arch

    # Validate that desired pods = number of arch workers
    desired=$($KUBECTL get daemonset -l name=multiarch-test-${_arch} --namespace=${NAMESPACE} --no-headers | awk '{ print $2 }')
    [[ ${#workers[@]} -eq $desired ]]
}

@test "Multiarch | s390x pods started successfully" {

    _arch="s390x"
    workers=( $($KUBECTL get nodes --no-headers --show-labels -l node-role.kubernetes.io/worker=true,beta.kubernetes.io/arch=${_arch} | awk '{ print $1 }') )
    # Skip if we don't have amd64 workers in the cluster
    if [[ "${#workers[@]}" -eq  0 ]]; then
      skip "No ${_arch} workers found in cluster"
    fi

    num_available=$(wait_and_getpods_running ${#workers[@]} ${_arch})

    # Check the pod Running number
    [[ $num_available -eq ${#workers[@]} ]]
}

@test "Multiarch | s390x pods outputting correctly" {

    _arch="s390x"
    workers=( $($KUBECTL get nodes --no-headers --show-labels -l node-role.kubernetes.io/worker=true,beta.kubernetes.io/arch=${_arch} | awk '{ print $1 }') )
    # Skip if we don't have s390x workers in the cluster
    if [[ "${#workers[@]}" -eq  0 ]]; then
      skip "No ${_arch} workers found in cluster"
    fi

    # Attempt to wait for containers to be ready
    local _desired="${#workers[@]}"
    waitfor_containersrunning $_arch $_desired
    output_correctly=$($KUBECTL --namespace=${NAMESPACE}  logs -l name=multiarch-test-${_arch} | grep container_started | wc -l )

    # Cleanup
    $KUBECTL --namespace=${NAMESPACE} delete daemonset -l name=multiarch-test-${_arch}

    # Check all containers outputted as expected
    [[ $output_correctly -eq ${#workers[@]} ]]
}

# All architectures
@test "Multiarch | Create daemonset on all workers" {

    _arch="all"
    workers=( $($KUBECTL get nodes --no-headers --show-labels -l node-role.kubernetes.io/worker=true | awk '{ print $1 }') )
    # Deploy daemonset
    deploy $_arch

    # Validate that desired pods = number of arch workers
    desired=$($KUBECTL get daemonset -l name=multiarch-test-${_arch} --namespace=${NAMESPACE} --no-headers | awk '{ print $2 }')
    [[ ${#workers[@]} -eq $desired ]]
}

@test "Multiarch | all pods started successfully" {

    _arch="all"

    num_available=$(wait_and_getpods_running ${#all_workers[@]} ${_arch})

    # Check the pod Running number
    [[ $num_available -eq ${#workers[@]} ]]
}

@test "Multiarch | all pods outputting correctly" {

    _arch="all"
    workers=( $($KUBECTL get nodes --no-headers --show-labels -l node-role.kubernetes.io/worker=true | awk '{ print $1 }') )
    # Attempt to wait for containers to be ready
    local _desired="${#workers[@]}"
    waitfor_containersrunning $_arch $_desired
    output_correctly=$($KUBECTL --namespace=${NAMESPACE}  logs -l name=multiarch-test-${_arch} | grep container_started | wc -l )

    # Cleanup
    $KUBECTL --namespace=${NAMESPACE} delete daemonset -l name=multiarch-test-${_arch}

    # Check all containers outputted as expected
    [[ $output_correctly -eq ${#workers[@]} ]]
}
