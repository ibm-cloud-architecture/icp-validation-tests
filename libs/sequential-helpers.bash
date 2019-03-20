ENV_READY_SLEEP=${ENV_READY_SLEEP:-5}
ENV_READY_TIMEOUT=${ENV_READY_TIMEOUT:-120}

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
        if [[ -z ${ON_SETUP_FAIL} ]]; then
          # The default behavior will be to skip
          export ON_SETUP_FAIL="skip"
        fi
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

      if [[ ! $_timeout -lt $(( $_attempt * ${ENV_READY_SLEEP} )) ]]; then
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
    # If last test in case clean up tmp files
    files=( "${tmp}-setup.skip" "${tmp}-setup.fail" "${tmp}-system.skip" \
            "${tmp}-system.fail" "${tmp}-subsequent.skip" "${tmp}-subsequent.fail" \
            "${tmp}-applicable.skip" )
    for file in ${files[*]}; do
      if [[ -e ${file} ]]; then
        rm ${file}
      fi
    done

    if type -t destroy_environment >/dev/null ; then
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

# export -f skip_subsequent
# export -f fail_subsequent
