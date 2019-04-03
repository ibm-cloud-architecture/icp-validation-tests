#!/usr/bin/env bash
# Helper functions specific to manage ICP and Kubernetes
# This is used as a helper for run.sh
########
function auth_and_create_context() {

  # Local variables
  username=$1
  password=$2
  context_name=$3

  # Now get authentication token
  token=$(curl -s -k -H "Content-Type: application/x-www-form-urlencoded;charset=UTF-8" -d "grant_type=password&username=${username}&password=${password}&scope=openid%20email%20profile" https://${SERVER}:8443/idprovider/v1/auth/identitytoken --insecure | jq .id_token | awk  -F '"' '{print $2}')

  # Create or update our kubeconfig
  kube="kubectl --kubeconfig=${GLOBAL_TMPDIR}/kubeconfig"
  $kube config set-cluster ${context_name} --server=https://${SERVER}:${KUBE_APISERVER_PORT} --insecure-skip-tls-verify=true
  $kube config set-context ${context_name} --cluster=${context_name}
  $kube config set-credentials $username --token=$token
  $kube config set-context ${context_name} --user=${username} --namespace=${NAMESPACE}

}

function kube() {
  kube="kubectl --kubeconfig=${GLOBAL_TMPDIR}/kubeconfig --context=basecontext"
  $kube "$@"
}

export -f kube

function rotate_namespace() {
  kube="kubectl --kubeconfig=${GLOBAL_TMPDIR}/kubeconfig --context=basecontext"

  # Determine the current namespace
  curname=$( $kube config get-contexts $($kube config current-context) --no-headers | awk '{print $5}')

  # Get the number if namespace is numbered
  curnum=${curname##${_NAMESPACE_BASE}}

  # Calculate next number in sequence
  nextnum=$(( $curnum + 1))

  # Set the new namespace
  export NAMESPACE="${_NAMESPACE_BASE}${nextnum}"
  $kube config set-context $($kube config current-context) --namespace=${NAMESPACE}

  $kube create namespace ${NAMESPACE}

}

export -f rotate_namespace

function run_as() {
  while getopts ":u:n:" arg; do
    case "${arg}" in
      u)
        user="${OPTARG}"
        ;;
      n)
        ns="${OPTARG}"
        ;;
      :)
        echo "run_as: Missing option argument for -$OPTARG in command $0 $*" >&2
        exit 1
        ;;
    esac
  done

  shift $((OPTIND-1))
  if [[ -z ${user} ]]; then
    user=$1
    shift
  fi

  "$@"
}


function run_in() {

  while getopts ":u:n:" arg; do
    case "${arg}" in
      u)
        user="${OPTARG}"
        ;;
      n)
        ns="${OPTARG}"
        ;;
      :)
        echo "run_in: Missing option argument for -$OPTARG in command $0 $*" >&2
        exit 1
        ;;
    esac
  done

  shift $((OPTIND-1))
  if [[ -z ${ns} ]]; then
    ns=$1
    shift
  fi

  "$@"
}

function populate_global_vars() {
  # This function will set some globally available version definitions
  # Can be run after kubectl is authenticated

  local versions=$(kubectl version --output=json)

  # Kubernetes Server Versions
  export K8S_SERVERVERSION_MAJOR=$(echo $versions | jq -r .serverVersion.major )
  export K8S_SERVERVERSION_MINOR=$(echo $versions | jq -r .serverVersion.minor )
  export K8S_SERVERVERSION_STR=$(echo $versions | jq -r .serverVersion.gitVersion )

  # Kubectl client version
  export K8S_CLIENTVERSION_MAJOR=$(echo $versions | jq -r .clientVersion.major )
  export K8S_CLIENTVERSION_MINOR=$(echo $versions | jq -r .clientVersion.minor )
  export K8S_CLIENTVERSION_STR=$(echo $versions | jq -r .clientVersion.gitVersion )

  # Attempt to detect ICP Version

  ## At least since 3.1.0 ICP version has been set in platform-ui env variables
  local icp_version=$(kubectl -n kube-system  describe daemonset platform-ui | grep ICP_VERSION | awk '{ print $2 }')
  if [[ ! -z icp_version && $icp_version != latest ]]; then
    # Attempt to break apart the version number
    export ICPVERSION_MAJOR=$(echo $icp_version | cut -d. -f1)
    export ICPVERSION_MINOR=$(echo $icp_version | cut -d. -f2)
    export ICPVERSION_PATCH=$(echo $icp_version | cut -d. -f3)
    export ICPVERSION_REV=$(echo $icp_version | cut -d. -f4)
  fi
  export ICPVERSION_STR=$icp_version

  # cloudctl can also work
  #cloudctl version
  # Client Version: 3.1.2-dev+d7f5a8646c8d63d2584095804f8d3ef9748b320c
  # Server Version: 3.1.1-973+c18caee2d82dc45146f843cb82ae7d5c28da7bc7

  export API_VERSIONS=( $(kubectl api-versions) )
}

function make_privileged_namespace() {
  ns=${1}

  echo "# Checking the rolebinding"
  if [[ $(kubectl get rolebinding privileged-psp-user -n $ns --no-headers --ignore-not-found | wc -l | sed 's/^ *//') -eq 0 ]]; then
    # Create rolebinding
    echo "# Creating the rolebinding"

    if [[ ! -z ${ICPVERSION_STR} && ${ICPVERSION_STR} != latest ]]; then
      # Detect role to use from ICP version
      if [[ ${ICPVERSION_MAJOR} -ge 3 && ${ICPVERSION_MINOR} -ge 1 && ${ICPVERSION_PATCH} -ge 0 ]]; then
        # ICP 3.1.0 and newer has ibm-privileged-clusterrole
        kubectl create rolebinding  privileged-psp-user  --clusterrole=ibm-privileged-clusterrole --serviceaccount=${ns}:default -n ${ns}
      else
        kubectl create rolebinding  privileged-psp-user  --clusterrole=privileged --serviceaccount=${ns}:default -n ${ns}
      fi
    # If we don't know the ICP version, attempt to guess from kubernetes server version
  elif [[ ${ICPVERSION_STR} == latest ]]; then
    kubectl create rolebinding  privileged-psp-user  --clusterrole=ibm-privileged-clusterrole --serviceaccount=${ns}:default -n ${ns}
  else
      # Attempt to detect from kubernetes version
      if [[ ${K8S_SERVERVERSION_MAJOR} -eq 1 && ${K8S_SERVERVERSION_MINOR} -ge 11 ]]; then
        kubectl create rolebinding  privileged-psp-user  --clusterrole=privileged --serviceaccount=${ns}:default -n ${ns}
      else
        kubectl create rolebinding  privileged-psp-user  --clusterrole=ibm-privileged-clusterrole --serviceaccount=${ns}:default -n ${ns}
      fi
    fi
  fi
}
