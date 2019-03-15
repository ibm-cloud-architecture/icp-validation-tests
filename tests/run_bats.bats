#!/usr/bin/env bats
part="$(basename ${BATS_TEST_FILENAME})"
load helpers

source ${APP_ROOT}/run.sh

@test "${part} | group run | any fail should fail function" {
  # Set the SUITE to the mock dir
  export TEST_SUITE_ROOT=${BATS_TEST_DIRNAME}/mocks

  # Populate groups
  export test_groups=("results" "results2")

  # Populate cases with some fail some pass
  export bats_files=("${TEST_SUITE_ROOT}/results/pass-skip-fail.bats" "${TEST_SUITE_ROOT}/results2/pass-pass.bats")

  export GROUP_RUNS="true"

  # Get the cases in those mock groups
  export -f run_bats

  run run_bats
  [[ ${status} -eq 1 ]]
}

@test "${part} | group run | all pass should pass function" {
  # Set the SUITE to the mock dir
  export TEST_SUITE_ROOT=${BATS_TEST_DIRNAME}/mocks

  # Populate groups
  export test_groups=("results" "results2")

  # Populate cases that all succeed
  export bats_files=("${TEST_SUITE_ROOT}/results/pass-pass-pass.bats" "${TEST_SUITE_ROOT}/results2/pass-pass.bats")

  export GROUP_RUNS="true"

  # Get the cases in those mock groups
  export -f run_bats

  run run_bats
  [[ ${status} -eq 0 ]]
}

@test "${part} | single run | any fail should fail function" {

  # Set the SUITE to the mock dir
  export TEST_SUITE_ROOT=${BATS_TEST_DIRNAME}/mocks

  # Populate groups
  export test_groups=("results" "results2")

  # Populate cases
  export bats_files=("${TEST_SUITE_ROOT}/results/pass-skip-fail.bats" "${TEST_SUITE_ROOT}/results2/pass-pass.bats")

  # Get the cases in those mock groups
  export BATS_OUTPUT="tap"
  export -f run_bats

  # Run bats
  run run_bats

  [[ ${status} -eq 1 ]]
  [[ ${lines[0]} == "1..5" ]]
  [[ ${lines[3]} == "not ok 3 fail the other" ]]

}

@test "${part} | single run | all success should pass function" {

  # Set the SUITE to the mock dir
  export TEST_SUITE_ROOT=${BATS_TEST_DIRNAME}/mocks

  # Populate groups
  export test_groups=("results" "results2")

  # Populate cases
  export bats_files=("${TEST_SUITE_ROOT}/results/pass-pass-pass.bats" "${TEST_SUITE_ROOT}/results2/pass-pass.bats")

  # Get the cases in those mock groups
  export BATS_OUTPUT="tap"
  export -f run_bats

  # Run bats
  run run_bats
  [[ ${status} -eq 0 ]]
  [[ ${lines[0]} == "1..5" ]]

}

@test "${part} | group run | run all cases ordered per group" {
  skip "test not implemented yet"
  # Group1,2,3

  run run_bats
  [[ ${lines[0]} == "group1 identifier" ]]
  [[ ${lines[0]} == "group 1 test count" ]]
  [[ ${lines[0]} == "group2 identifier" ]]
  [[ ${lines[0]} == "group 2 test count" ]]
  [[ ${lines[0]} == "group2 identifier" ]]
  [[ ${lines[0]} == "group 2 test count" ]]
}
