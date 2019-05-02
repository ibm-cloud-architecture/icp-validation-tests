# Set defaults that can be overwritten
export ENV_READY_SLEEP=${ENV_READY_SLEEP:-5}
export ENV_READY_TIMEOUT=${ENV_READY_TIMEOUT:-120}
export ON_SETUP_FAIL=${ON_SETUP_FAIL:-failfirst}
export ROTATE_NAMESPACE=${ROTATE_NAMESPACE:-false}
export ON_ASSERT_FAIL=${ON_ASSERT_FAIL:-skip_subsequent}

function setup() {
  tmp=${BATS_TMPDIR}/${BATS_TEST_DIRNAME##*/}${BATS_TEST_FILENAME##*/}
  if [[ ${BATS_TEST_NUMBER} -eq 1 ]]; then

    # First check if we're applicable
    if type -t applicable >/dev/null ; then
      if ! applicable ; then
        # Set applicability skip
        touch ${tmp}-applicable.skip
        skip "Not applicable in this environment"
      fi
    fi

    # Prepare environment for test cases
    if type -t create_environment >/dev/null ; then
      if ! create_environment ; then
        # The setup failed.
        case "${ON_SETUP_FAIL}" in
          skip)
            # Skip all tests in this case
            touch ${tmp}-setup.skip
            ;;
          fail)
            # Fail all tests in this case
            touch ${tmp}-setup.fail
            ;;
          failfirst)
            # Skip all subsequent tests in this case
            touch ${tmp}-setup.skip
            echo "Environment setup failed" >&2
            return 1
            ;;
          *)
            echo "Unknown value '${ON_SETUP_FAIL}' for ON_SETUP_FAIL" > ${tmp}-system.fail
            return 1
            ;;
        esac
      fi
    fi

    # If defined wait for environment to become ready
    if type -t environment_ready >/dev/null ; then
      _timeout=${ENV_READY_TIMEOUT}
      _attempt=1
      while ! environment_ready && [[ $_timeout -gt $(( $_attempt * ${ENV_READY_SLEEP} )) ]]; do
        sleep ${ENV_READY_SLEEP}
        _attempt=$(($_attempt+1))
      done
      if [[ $_timeout -le $(( $_attempt * ${ENV_READY_SLEEP} )) ]]; then
        # We timed out waiting for environment to become ready. Skip subsequent tests
        case "${ON_SETUP_FAIL}" in
          skip)
            # Skip all tests in this case
            touch ${tmp}-setup.skip
            ;;
          fail)
            # Fail all tests in this case
            touch ${tmp}-setup.fail
            ;;
          failfirst)
            # Skip all subsequent tests in this case
            touch ${tmp}-setup.skip
            echo "Timed out waiting for environment to become ready" >&2
            return 1
            ;;
          *)
            echo "Unknown value '${ON_SETUP_FAIL}' for ON_SETUP_FAIL" > ${tmp}-system.fail
            return 1
            ;;
        esac

      fi

    fi

  fi



  # Now test if we're applicable
  if [[ -e ${tmp}-applicable.skip ]]; then
    skip "Not applicable in this environment"
  fi

  # And test if we should skip of fail because of prereqs
  if [[ -e ${tmp}-setup.skip ]]; then
    skip "Environment setup failed"
  fi

  if [[ -e ${tmp}-setup.fail ]]; then
    echo "Environment setup failed" >&2
    return 1
  fi

  # Check for systemic problems with the framework
  if [[ -e ${tmp}-system.fail ]]; then
    cat ${tmp}-system.fail >&2
    return 1
  fi

  # Check if we should skip of fail because of previous tests in the file
  if [[ -e ${tmp}-subsequent.fail ]]; then
    echo "Not testing because previous test failure" >&2
    return 1
  fi

  if [[ -e ${tmp}-subsequent.skip ]]; then
    skip "Previous tests failed"
  fi
}

function teardown() {

  if [[ $BATS_TEST_NUMBER -eq ${#BATS_TEST_NAMES[@]} ]]; then

    # Check if we need to rotate the namespace
    if [[ ! -z ${ROTATE_NAMESPACE} && ! "${ROTATE_NAMESPACE}" == "false" ]]; then

      # Detect if we have failed at all. If we have, rotate the workspace and don't clean up
      case "${ROTATE_NAMESPACE}" in
        on_setup_fail)
          # Detect if we have failed setup
          if [[ -e ${tmp}-setup.fail || -e ${tmp}-setup.skip ]]; then
            rotate_namespace
            _skip_destroy="true"
          fi
          ;;
        on_test_fail)
          # Detect if we have failed a test case
          if [[ -e ${tmp}-subsequent.fail || -e ${tmp}-subsequent.skip ]]; then
            rotate_namespace
            _skip_destroy="true"
          fi
          ;;
        on_any_fail)
          # Detect if we have failed or skipped
          if [[ -e ${tmp}-setup.fail || -e ${tmp}-setup.skip ||  -e ${tmp}-subsequent.fail || -e ${tmp}-subsequent.skip ]]; then
            rotate_namespace
            echo "we rotated namspace" >> /tmp/debug.log
            _skip_destroy="true"
          fi
          ;;
      esac
    fi

    # clean up tmp files
    files=( "${tmp}-setup.skip" "${tmp}-setup.fail" "${tmp}-system.skip" \
            "${tmp}-system.fail" "${tmp}-subsequent.skip" "${tmp}-subsequent.fail" \
            "${tmp}-applicable.skip" )
    for file in ${files[*]}; do
      if [[ -e ${file} ]]; then
        rm ${file}
      fi
    done

    if [[ $(type -t destroy_environment) && ! "$_skip_destroy" == "true" ]]; then
      echo "we destroy environment" >> /tmp/debug.log
      destroy_environment
    fi

  fi
}

function skip_subsequent() {
  touch ${tmp}-subsequent.skip
}

function fail_subsequent() {
  touch ${tmp}-subsequent.fail
}

function assert_or_bail() {
  if bash -c "$@" ; then
    return 0
  else
    if type -t "${ON_ASSERT_FAIL}" >/dev/null; then
      ${ON_ASSERT_FAIL}
    fi
    echo "$@ failed assertion" >&2
    return 1
  fi
}

# export -f skip_subsequent
# export -f fail_subsequent
