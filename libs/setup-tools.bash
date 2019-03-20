#!/usr/bin/env bash
# Functions to setup tools declared
# in tests CAPABILITIES
# This is used as a helper for run.sh
########


#####
# kubectl specific function
#####

function setup_kubectl() {
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
      dl_url="curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
      ;;
    'Darwin x86_64')
      dl_url="curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/darwin/amd64/kubectl"
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

# TODO Move this function
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

function config_kube_credentials() {
  # We will create our own kube config file where we control our own contexts


  if [[ ! -z ${USERNAME} && ! -z ${PASSWORD} && ! -z ${SERVER} ]]; then
    # Use this
    echo "# Using provided credentials"
  elif kubectl api-version &>/dev/null; then
    # If we have authenticated kubectl we'll use that to attempt to get credentials
    export USERNAME=$(kubectl get secrets platform-auth-idp-credentials -n kube-system -o jsonpath="{.data.admin_username}" | b64decode)
    export PASSWORD=$(kubectl get secrets platform-auth-idp-credentials -n kube-system -o jsonpath="{.data.admin_password}" | b64decode)
  fi

  # Now get authentication token
  token=$(curl -s -k -H "Content-Type: application/x-www-form-urlencoded;charset=UTF-8" -d "grant_type=password&username=${USERNAME}&password=${PASSWORD}&scope=openid" https://${SERVER}:${ROUTER_HTTPS_PORT}/idprovider/v1/auth/identitytoken --insecure | jq .id_token | awk  -F '"' '{print $2}')

  # Create or update our kubeconfig
  kube="kubectl --kubeconfig=${APP_ROOT}/bin/.kubeconfig"
  $kube config set-cluster ${CLUSTERNAME} --server=https://$SERVER:$KUBE_APISERVER_PORT --insecure-skip-tls-verify=true
  $kube config set-context ${CLUSTERNAME} --cluster=$CLUSTERNAME
  $kube config set-credentials $USERNAME --token=$token
  $kube config set-context ${CLUSTERNAME} --user=$USERNAME --namespace=${NAMESPACE}
  $kube config use-context ${CLUSTERNAME}

}
