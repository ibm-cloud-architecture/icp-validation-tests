#!/usr/bin/env bash
# wait-helper -- Helper to simplify waiting for certain condition
# -c "Command to run"
# -v "Optional: Retun value to wait for (default 0)"
# -o "Optional: Output string to wait for"
# -r "Optional: Retry interval (default 5 seconds)"
# -t "Optional: Timeout (default 60 seconds)"

# Use Example
# (Slightly inifficient example, but very self exmplanatory)
# wait_for "kubectl get pods | grep Ready | grep mypod"
# Uses default interval and default timeout to wait until mypod is in Ready state.
# returns 1 if not found before timeout limit, else 0


function _call_cmd() {

  if [[ ! -z ${_ret_val} ]]; then
    eval "${_cmd}"
    rv=$?
    if [[ $rv -eq ${_ret_val} ]]; then
      return 0
    else
      return 1
    fi
  fi

  if [[ ! -z ${_retoutput} ]]; then
    if [[ "$(eval ${_cmd})" =~ "${_retoutput}" ]]; then
      return 0
    else
      return 1
    fi
  fi
}

function wait_for() {
  # Set some defaults
  local retry_interval="5" # Retry command every 5 seconds
  local timeout="60" # Keep trying for 1 minute

  while getopts ":c:v:o:r:t:" arg; do
    case "${arg}" in
      c)
        #read -ra _cmd <<<"${OPTARG}"
        _cmd="${OPTARG}"
        ;;
      v)
        _ret_val=${OPTARG}
        ;;
      o)
        _retoutput=${OPTARG}
        ;;
      r)
        local retry_interval=${OPTARG}
        ;;
      t)
        local timeout=${OPTARG}
        ;;
      :)
        echo "wait_for: Missing option argument for -$OPTARG in command $0 $*" >&2
        exit 1
        ;;
    esac
  done

  # Set default if return value or output has not been set
  if [[ -z ${_ret_val} && -z ${_retoutput} ]]; then
    _ret_val="0"
  fi

  # If _cmd was not set, assume we can grab it from first parameter
  if [[ -z ${_cmd} ]]; then
    if [[ ! -z ${1} ]]; then
      _cmd="${1}"
    else
      echo "wait_for: Error: Called without argument"
      exit 1
    fi
  fi

  local attempt=0
  while ! _call_cmd && [[ $timeout -gt $(( $attempt * ${retry_interval} )) ]]; do
    sleep ${retry_interval}
    attempt=$(($attempt+1))
  done

  # Determine return code based on timeout status
  if [[ $timeout -gt $(( $attempt * ${retry_interval} )) ]]; then
    # We did not time out
    return 0
  else
    # We did time out
    return 1
  fi
}

# This enables the functions to be wrapped in other functions like the assert functions
export -f wait_for
export -f _call_cmd
