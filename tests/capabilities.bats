#!/usr/bin/env bats
part="$(basename ${BATS_TEST_FILENAME})"
load helpers

source ${APP_ROOT}/run.sh


@test "${part} | empty capabilities when no capabilities declared" {
  bats_tests=("${BATS_TEST_DIRNAME}/mocks/group1/g1-test1.bats" "${BATS_TEST_DIRNAME}/mocks/group1/g1-test2.bats")

  get_desired_capabilities

  [[ -z ${desired_capabilities} ]]
}

@test "${part} | detect capabilities" {
  export bats_tests=("${BATS_TEST_DIRNAME}/mocks/capabilities/kubectl.bats")

  get_desired_capabilities

  # [[ ! -z ${desired_capabilities} ]]
  [[ "${desired_capabilities[0]}" == "kubectl" ]]
}
