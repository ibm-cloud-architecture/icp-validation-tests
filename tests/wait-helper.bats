#!/usr/bin/env bats
part="$(basename ${BATS_TEST_FILENAME})"

load helpers
source ${APP_ROOT}/libs/wait-helper.bash

@test "${part} | Pipe non-found string to grep should time out" {
  run wait_for -c "echo foobar | grep baz" -t 1 -r 1
  [[ $status -eq 1 ]]
}

@test "${part} | Pipe found string to grep should not time out" {
  run wait_for -c "echo foobar | grep foo" -t 1 -r 1
  [[ $status -eq 0 ]]
}

@test "${part} | Command output not found should time out" {
  run wait_for -c "echo foobar" -o "baz" -t 1 -r 1
  [[ $status -eq 1 ]]
}

@test "${part} | Command output found should not time out" {
  run wait_for -c "echo foobar" -o "foo" -t 1 -r 1
  [[ $status -eq 0 ]]
}
