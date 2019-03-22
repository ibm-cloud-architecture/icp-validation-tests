#!/usr/bin/env bats
part="$(basename ${BATS_TEST_FILENAME})"
load helpers

source ${APP_ROOT}/libs/setup-tools.bash

export TEST_SUITE_ROOT=${BATS_TEST_DIRNAME}/mocks

@test "${part} | find kubectl in path" {

  # Mock up a which that finds kubectl in path
  function which() {
    echo "/usr/local/bin/kubectl"
    return 0
  }

  export -f which

  run find_or_download_kubectl

  [[ $status -eq 0 ]]
}

@test "${part} | no kubectl in path no download location no internet should fail" {

  # Mock up a which that does not find kubectl
  function which() {
    return 1
  }

  function curl() {
    return 1
  }

  function chmod() {
    return 0
  }
  export -f which
  export -f curl
  export -f chmod

  run setup_kubectl

  [[ $status -eq 1 ]]
  [[ ${lines[1]} == "# Unable to locate or download kubectl binary" ]]
}

@test "${part} | Download kubectl for osx from cluster" {

  # Create mockup of function
  function uname() {
    echo "Darwin x86_64"
  }

  function which() {
    return 1
  }

  function curl() {
    return 0
  }

  function chmod() {
    return 0
  }
  export -f uname
  export -f which
  export -f curl
  export -f chmod

  export SERVER="mymockserver"
  export USERNAME="mymockuser"
  export PASSWORD="mymockpass"

  run find_or_download_kubectl

  [[ ${status} -eq 0 ]]
  [[ ${output} =~ "# Attempting to download kubectl from ${SERVER}" ]]
}

@test "${part} | Download kubectl for linux from cluster" {

  # Create mockup of function
  function uname() {
    echo "Linux x86_64"
  }

  function which() {
    return 1
  }

  function curl() {
    return 0
  }

  function chmod() {
    return 0
  }
  export -f uname
  export -f which
  export -f curl
  export -f chmod

  export SERVER="mymockserver"
  export USERNAME="mymockuser"
  export PASSWORD="mymockpass"

  run find_or_download_kubectl

  [[ ${status} -eq 0 ]]
  [[ ${output} =~ "# Attempting to download kubectl from ${SERVER}" ]]
}

@test "${part} | Download kubectl for unknown platform from cluster" {

  # Create mockup of function
  function uname() {
    echo "Windows_NT x86_64"
  }

  function which() {
    return 1
  }

  function curl() {
    return 0
  }

  function chmod() {
    return 0
  }
  export -f uname
  export -f which
  export -f curl
  export -f chmod

  export SERVER="mymockserver"
  export USERNAME="mymockuser"
  export PASSWORD="mymockpass"

  run find_or_download_kubectl

  [[ ${status} -eq 1 ]]
  [[ ! ${output} =~ "# Attempting to download kubectl from ${SERVER}" ]]
}


@test "${part} | Download kubectl from internet" {

  # Create mockup of function
  function which() {
    return 1
  }

  function curl() {
    if [[ "$3" =~ "$SERVER" ]]; then
      return 1
    else
       return 0
    fi
  }

  function chmod() {
    return 0
  }

  export -f which
  export -f curl
  export -f chmod

  export SERVER="mymockserver"
  export USERNAME="mymockuser"
  export PASSWORD="mymockpass"

  run find_or_download_kubectl

  [[ ${status} -eq 0 ]]
  [[ ${lines[1]} == "# Attempting to download kubectl from internet" ]]
}
