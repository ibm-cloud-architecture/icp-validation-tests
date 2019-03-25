#!/usr/bin/env bats
part="$(basename ${BATS_TEST_FILENAME})"

load helpers

source ${APP_ROOT}/run.sh

@test "${part} | test_groups should unpopulated before function invoked" {
  [[ -z ${test_groups} ]]
}

@test "${part} | parse comma separated groups" {
  export TEST_SUITE_ROOT=${BATS_TEST_DIRNAME}/mocks
  parse_groups group1,group2,group3
  [[ ${#test_groups[@]} -eq 3 ]]
  [[ ${test_groups[0]} == "group1" ]]
  [[ ${test_groups[1]} == "group2" ]]
  [[ ${test_groups[2]} == "group3" ]]
}

@test "${part} | get groups from cases" {
  # Set the SUITE to the mock dir
  export TEST_SUITE_ROOT=${BATS_TEST_DIRNAME}/mocks

  # Populate groups, make sure to have multiple cases in each group
  export bats_files=("${BATS_TEST_DIRNAME}/mocks/group1/g1-test1.bats" \
     "${BATS_TEST_DIRNAME}/mocks/group1/g1-test2.bats" "${BATS_TEST_DIRNAME}/mocks/group2/g2-test1.bats" )

  # Get the groups for the mock cases
  get_groups

  [[ ${#test_groups[@]} -eq 2 ]]
  [[ ${test_groups[0]} == "group1" ]]
  [[ ${test_groups[1]} == "group2" ]]
}

@test "${part} | list available groups" {

  export TEST_SUITE_ROOT=${BATS_TEST_DIRNAME}/mocks

  run list_groups

  [[ ${output} =~ "group2" ]]

}
