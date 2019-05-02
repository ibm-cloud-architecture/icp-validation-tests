#!/usr/bin/env bash
# Functions to setup tools declared
# in tests CAPABILITIES
# This is used as a helper for run.sh
########

#####
# General helper functions
#####
function b64decode() {
  # Detect if can use base64 --decode or base64 -d
  if echo foobar | base64 --decode >/dev/null &>/dev/null ; then
    decode="base64 --decode"
  else
    # Assume busybox syntax will work for now
    decode="base64 -d"
  fi

  echo $($decode $1)
}

#####
# kubectl specific function
#####

function setup_kubectl() {
  echo "# Setting up kubectl"
  source ${APP_ROOT}/libs/icp-kube-functions.bash

  # Ensure that kubectl binary is available
  if ! find_or_download_kubectl; then
    echo "# Unable to locate or download kubectl binary"
    return 1
  fi

  # Configure credentials
  if ! config_kube_credentials; then
    echo "# Unable to get credentials for kubernetes environment."
    return 1
  fi

  # Populate ICP and Kubernetes specific global variables
  if ! populate_global_vars; then
    echo "# Unable to get version information to populate global vars"
    return 1
  fi
}


function find_or_download_kubectl() {
  # If kubectl is already in PATH we'll make do with that
  if which kubectl &>/dev/null; then
    return 0
  fi

  # See if we have downloaded it to local tool directory before
  if [[ -x ${APP_ROOT}/bin/kubectl ]]; then
    export PATH="${APP_ROOT}/bin:${PATH}"
    return 0
  fi

  # Make sure bin directory exists
  mkdir -p ${APP_ROOT}/bin

  # Attempt to download kubectl from ICP environment
  if [[ ! -z ${SERVER} ]]; then
    case "$(uname -sm)" in
      'Linux x86_64')
        dl_url="https://$SERVER:$ROUTER_HTTPS_PORT/api/cli/kubectl-linux-amd64"
        ;;
      'Darwin x86_64')
        dl_url="https://$SERVER:$ROUTER_HTTPS_PORT/api/cli/kubectl-darwin-amd64"
        ;;
      *)
        # Unknown or unsupported platform
        ;;
    esac
  fi

  if [[ ! -z ${dl_url} ]]; then
    echo "# Attempting to download kubectl from ${SERVER}"
    curl -kLo ${APP_ROOT}/bin/kubectl ${dl_url} && \
    chmod a+x ${APP_ROOT}/bin/kubectl && \
    export PATH="${APP_ROOT}/bin:${PATH}" && \
    return 0
  fi

  # Fall back on download from internet
  case "$(uname -sm)" in
    'Linux x86_64')
      dl_url="https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
      ;;
    'Darwin x86_64')
      dl_url="https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/darwin/amd64/kubectl"
      ;;
    *)
      # Unknown or unsupported platform
      ;;
  esac

  if [[ ! -z ${dl_url} ]]; then
    echo "# Attempting to download kubectl from internet"
    curl -kLo ${APP_ROOT}/bin/kubectl ${dl_url} && \
    chmod a+x ${APP_ROOT}/bin/kubectl && \
    export PATH="${APP_ROOT}/bin:${PATH}" && \
    return 0
  fi

  # If we still haven't got it we fail here
  return 1
}

function config_kube_credentials() {
  # We will create our own kube config file where we control our own contexts
  if [[ ! -z ${USERNAME} && ! -z ${PASSWORD} && ! -z ${SERVER} ]]; then
    # Use this
    echo "# Using provided credentials"
  elif kubectl api-versions &>/dev/null; then
    # If we have authenticated kubectl we'll use that to attempt to get credentials
    read -r ubase pbase <<<$(kubectl get secrets platform-auth-idp-credentials -n kube-system -o jsonpath="{.data.admin_username} {.data.admin_password}")

    export USERNAME=$(echo ${ubase} | b64decode)
    export PASSWORD=$(echo ${pbase} | b64decode)
    export SERVER=$(kubectl -n kube-public get configmap ibmcloud-cluster-info -o jsonpath='{.data.cluster_address}')
  else
    echo "Unable to find kubernetes credentials. Please provide"
    return 1
  fi

  # Create or update our kubeconfig

  if ! auth_and_create_context ${USERNAME} ${PASSWORD} basecontext ; then
    echo "Problems authenticating with $SERVER"
    return 1
  fi
  
  kube config use-context basecontext

}

function setup_namespace() {
  echo "# Setting up namespace"

  # Ensure that the original namespace name is saved for rotate_namespace
  export _NAMESPACE_BASE=${NAMESPACE}

  # Setup the namespace as appropriate
  if ! kube create namespace ${NAMESPACE} ; then
    # Namespace probably already existed. Not to worry
    echo "# Warning: Problems creating namespace. It may already have existed."
  fi

  # Ensure admission policy if needed
  if [[ "${API_VERSIONS[@]}" =~ "securityenforcement.admission" ]]; then
    kube -n ${NAMESPACE} apply -f ${APP_ROOT}/imagepolicy.yaml
  fi

  make_privileged_namespace ${NAMESPACE}

  return 0
}
