#!/usr/bin/env bats
part="$(basename ${BATS_TEST_FILENAME})"
load helpers

source ${APP_ROOT}/run.sh

@test "${part} | bats_files should unpopulated before function invoked" {
  [[ -z ${bats_files} ]]
}

@test "${part} | get_cases | get cases from specified groups" {
  # Set the SUITE to the mock dir
  export TEST_SUITE_ROOT=${BATS_TEST_DIRNAME}/mocks

  # Populate groups
  export test_groups=("group1" "group3")


  # Get the cases in those mock groups
  get_cases

  [[ ${#bats_files[@]} -eq 4 ]]
  [[ ${bats_files[0]} == "${BATS_TEST_DIRNAME}/mocks/group1/g1-test1.bats" ]]
  [[ ${bats_files[1]} == "${BATS_TEST_DIRNAME}/mocks/group1/g1-test2.bats" ]]
  [[ ${bats_files[2]} == "${BATS_TEST_DIRNAME}/mocks/group3/g3-test1.bats" ]]
  [[ ${bats_files[3]} == "${BATS_TEST_DIRNAME}/mocks/group3/g3-test2.bats" ]]

}

@test "${part} | parse_cases | parse case input" {
  # Set the SUITE to the mock dir
  export TEST_SUITE_ROOT=${BATS_TEST_DIRNAME}/mocks

  # Get bats files from specified cases
  parse_cases g1-test1,g1-test2,g2-test1,g3-test2

  [[ ${#bats_files[@]} -eq 4 ]]
  [[ ${bats_files[0]} == "${BATS_TEST_DIRNAME}/mocks/group1/g1-test1.bats" ]]
  [[ ${bats_files[1]} == "${BATS_TEST_DIRNAME}/mocks/group1/g1-test2.bats" ]]
  [[ ${bats_files[2]} == "${BATS_TEST_DIRNAME}/mocks/group2/g2-test1.bats" ]]
  [[ ${bats_files[3]} == "${BATS_TEST_DIRNAME}/mocks/group3/g3-test2.bats" ]]

}
