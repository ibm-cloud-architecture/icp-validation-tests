
function setup() {
  tmp=${BATS_TMPDIR}/${BATS_TEST_DIRNAME##*/}${BATS_TEST_FILENAME##*/}
  if [[ ${BATS_TEST_NUMBER} -eq 1 ]]; then

    # First check if we're applicable
    if type -t applicable >/dev/null ; then
      if ! applicable ; then
        # Set applicability skip
        touch ${tmp}-applicable.skip
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
