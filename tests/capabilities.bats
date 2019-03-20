#!/usr/bin/env bats
part="$(basename ${BATS_TEST_FILENAME})"
load helpers

source ${APP_ROOT}/run.sh

export TEST_SUITE_ROOT=${BATS_TEST_DIRNAME}/mocks

@test "${part} | empty capabilities when no capabilities declared" {
  bats_files=("${TEST_SUITE_ROOT}/group1/g1-test1.bats" "${TEST_SUITE_ROOT}/group1/g1-test2.bats")

  get_desired_capabilities

  [[ -z ${desired_capabilities} ]]
}

@test "${part} | detect capabilities" {
  export bats_files=("${TEST_SUITE_ROOT}/capabilities/kubectl.bats")

  get_desired_capabilities

  [[ "${desired_capabilities[0]}" == "kubectl" ]]
}
