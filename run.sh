#!/usr/bin/env bash

# This allows the script to be sourced for bats unit testing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  export APP_ROOT="$(dirname "$($(type -p greadlink readlink | head -1) -f  "$BASH_SOURCE")")"
fi

# Load global default settings
source ${APP_ROOT}/defaults.sh

# Load helper funktions
source ${APP_ROOT}/libs/setup-tools.bash
source ${APP_ROOT}/libs/icp-kube-functions.bash

# Global variables that will be populated for test runs
declare -a test_groups
declare -a bats_files

function print_help() {
    echo "Accepted cli arguments are:"
    echo -e "\t[--help|-h ]. prints this help"
    echo -e "\t[--all|-a ]. Run all cases"
    echo -e "\t[--groups|-g <groups> ], the case groups should be like --groups='group1,group2'."
    echo -e "\t[--groups|-g -l ], list the current supported groups."
    echo -e "\t[--ignore_groups|-ng <groups> ], skip the cases groups,like -ng group1,group2"
    echo -e "\t[--cases|-c <cases>], the cases should be like --cases='case1,case2'."
    echo -e "\t[--cases|-c -l], list the current supported cases."
    echo -e "\t[--ignore_cases|-nc <cases> ], skip the cases groups,like -nc case1,case2"
}

####
# Functions used to construct the global
# $test_groups and $bats_files variables
###

# Parse groups from input
function parse_groups() {
  groups=$1
  while read -d ',' group ; do
    if [[ ! -d ${TEST_SUITE_ROOT}/${group} ]]; then
      exit_error "Could not find group ${group}"
    fi
    test_groups+=( $group )
  done < <(echo ${groups},)
  export test_groups
}

# Get groups from specified test cases
function get_groups() {

  for file in "${bats_files[@]}"; do
    group=$(basename $( dirname ${file} ))
    if [[ ! " ${test_groups[@]} " =~ " ${group} " ]]; then
      test_groups+=( ${group} )
    fi
  done

  export test_groups
}

# List available groups
function list_groups() {
  ls -1 ${TEST_SUITE_ROOT}
}

# Parse cases from input
function parse_cases() {

  cases=$1
  # Find the full path of the specified cases
  while read -d ',' case ; do
    bats_files+=( $(ls ${TEST_SUITE_ROOT}/*/${case}.bats) )
  done < <(echo ${cases},)

  export bats_files
}

function get_cases() {
  # Get cases based on populated $test_groups global
  for group in ${test_groups[*]}; do
    for test in $(ls ${TEST_SUITE_ROOT}/${group}/*.bats); do
      bats_files+=( ${test} )
    done
  done
  export bats_files
}

# List available cases
function list_cases() {
  basename $(ls -1 ${TEST_SUITE_ROOT}/*/*.bats)
}

####
# Bats execution handling
####

# Run bats based on populed $test_groups and $bats_files
function run_bats() {

  if [[ "${GROUP_RUNS}" == "true" ]]; then
    $output_format="--${BATS_OUTPUT}"

    # Separate bats runs by groups
    for group in ${test_groups[*]}; do
      declare -a runcases
      # Get all the test cases in the curren group
      for case in ${bats_files[*]}; do
        if [[ $case =~ .*/${group}/.*\.bats ]]; then
          runcases+=( $case )
        fi
      done
      echo "# ==> $group"
      bats ${output_format} ${runcases[@]}
      if [[ $? -ne 0 ]]; then
          export EXIT_STATUS=1
      fi
      unset runcases
    done
  else

    # Run all cases in a single bats run
    bats ${output_format} ${bats_files[@]}
    if [[ $? -ne 0 ]]; then
        export EXIT_STATUS=1
    fi
  fi

  return ${EXIT_STATUS}

}

####
# Runtime environment handling
####

function prepare_environment() {
  if [[ "${PREINSTALL_TEST_PREREQS}" == "true" ]]; then
    get_desired_capabilities
  fi

  # Ensure the desired capabilities are available and configured
  if [[ ! -z ${desired_capabilities} ]]; then
    for capability in "${desired_capabilities[@]}"; do
      if [[ "$(type -t setup_${capability})" == "function" ]]; then
        # All these functions are defined in setup-tools.bash
        if ! setup_${capability} ; then
          exit_error "Error performing setup_${capability}"
        fi
      fi
    done
  fi
}

function get_desired_capabilities() {

  # Include implicit capability requirements
  desired_capabilities=( ${IMPLICIT_CAPABILITIES[*]} )

  # Scan all bats files for explicit capability requirements
  for file in ${bats_files[*]}; do
    source <(grep "^CAPABILITIES=" ${file}) # TODO This may be unsafe, consider different method

    if [[ ! -z ${CAPABILITIES} ]]; then
      for capability in ${CAPABILITIES[*]}; do
        if [[ ! " ${desired_capabilities[@]} " =~ " ${capability} " ]]; then
          desired_capabilities+=( ${capability} )
        fi
      done
      unset CAPABILITIES
    fi
  done

  export desired_capabilities

}

function exit_error() {
  echo "${1}"
  exit 1
}

function wrapper_cleanup() {
  # Cleanup the global temp dir, after a quick sanity check
  if [[ ! "${GLOBAL_TMPDIR}" =~ ^(/.*/.+).* ]]; then
    echo # WARNING: GLOBAL_TMPDIR ${GLOBAL_TMPDIR} does not seem safe to delete. Will not delete
  else
    rm -rf ${GLOBAL_TMPDIR}
  fi
}

####
# Functions used when running $0 from the command line
####

function parse_args() {
  while [[ $# != 0 ]]; do
    case $1 in
      'test')

        export TEST_SUITE_ROOT="$(pwd)/tests/mocks"
        # Populate groups

        # Populate groups
        #export test_groups=("results" "results2")


        # Populate cases
        #export bats_files=("${TEST_SUITE_ROOT}/results/pass-skip-fail.bats" "${TEST_SUITE_ROOT}/results2/pass-pass.bats")

        #export GROUP_RUNS="true"
        # run_bats
        #
        # parse_groups capabilities
        #
        # echo "number ${#test_groups[@]}"
        # echo ${test_groups[@]}
        # get_cases
        # get_desired_capabilities
        # echo $desired_capabilities
        #
        function which() {
          return 1
        }

        function curl() {
          if [[ "$*" =~ "$SERVER" ]]; then
            return 1
          else
             return 1
          fi
        }

        function chmod() {
          return 0
        }

        export -f which
        export -f curl

        export SERVER="mymockserver"
        export USERNAME="mymockuser"
        export PASSWORD="mymockpass"

        #set -x
        setup_kubectl
        #set +x
        # echo $?
        exit 0
        ;;

      '--all'|-a)
        test_groups=($(list_groups))
        get_cases
        prepare_environment
        run_bats
        exit ${EXIT_STATUS}
        ;;

      '--groups'|-g)
        if [[ "$2" == "-l" ]]; then
          list_groups
          exit 0
        elif [[ "$2" == "" ]]; then
          print_help
          exit_error "You must specify list of groups to run"
        fi

        # Run the test based on the groups we've been given
        parse_groups $2
        get_cases
        prepare_environment
        run_bats
        exit ${EXIT_STATUS}
        ;;
      '--cases'|-c)
        if [[ "$2" == "-l" ]]; then
          list_cases
          exit 0
        elif [[ "$2" == "" ]]; then
          print_help
          exit_error "You must specify list of cases to run"
        fi

        parse_cases $2
        get_groups
        prepare_environment
        run_bats
        exit ${EXIT_STATUS}
        ;;
      '--ignore_groups'|-ng)
          # here we will probably do get_all then deduct ignored
          exit_error "Not implemented yet"
          ;;
      '--ignore_cases'|-nc)
          exit_error "Not implemented yet"
          ;;
      '--help'|-h)
        print_help
        exit 0
         ;;
      *)
        help
        exit 1
         ;;
    esac
  done
}


####
# Script execution handling
####

# This allows the script to be sourced for bats unit testing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -eq 0 ]]; then
    print_help
    exit 0
  else

    # Create a global temp dir that persists between bats runs
    if type -p mktemp >/dev/null; then
      export GLOBAL_TMPDIR=$(mktemp -d)
    fi
    if [[ -z ${GLOBAL_TMPDIR} ]]; then
      if [[ -z "$TMPDIR" ]]; then
        export GLOBAL_TMPDIR="/tmp/icpvalidation-$$"
      else
        export GLOBAL_TMPDIR="${TMPDIR%/}/icpvalidation-$$"
      fi
    fi
    mkdir -p ${GLOBAL_TMPDIR}
    trap 'wrapper_cleanup' EXIT

    # Parse arguments and execute relevant actions
    parse_args "$@"
  fi
fi
