#!/usr/bin/env bats
part="$(basename ${BATS_TEST_FILENAME})"

load helpers

@test "${part} | No params should print help" {
  run ${APP_ROOT}/run.sh
  [[ $status -eq 0 ]]
  [[ ${lines[0]} == "Accepted cli arguments are:" ]]
}

@test "${part} | --help should print help" {
  run ${APP_ROOT}/run.sh --help
  [[ $status -eq 0 ]]
  [[ ${lines[0]} == "Accepted cli arguments are:" ]]
}

@test "${part} | -h should print help" {
  run ${APP_ROOT}/run.sh
  [[ $status -eq 0 ]]
  [[ ${lines[0]} == "Accepted cli arguments are:" ]]
}

@test "${part} | Should default to not group runs" {
  source ${APP_ROOT}/run.sh
  [[ "${GROUP_RUNS}" == "false" ]]
}

@test "${part} | Should default to bats pretty print" {
  # Pretty print should be default so end users
  # running from docker get a reasonable summary output
  source ${APP_ROOT}/defaults.sh

  [ "${BATS_OUTPUT}" == "pretty" ]
}
