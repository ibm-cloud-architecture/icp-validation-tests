#!/usr/bin/env bats
test="Fail Subsequent"
load ../../helpers
load ${sert_bats_workdir}/framework.bash


@test "${test} | Simple 1 | Always pass1" {

  if [[ ! "foo" == "bar" ]]; then
    skip_subsequent
  fi

  [[ 0 -eq 0 ]]
}

@test "${test} | Simple 1 | Fail this one" {

  v="foo"

  if [[ ! "${v}" == "bar" ]]; then
    skip_subsequent
  fi

  [ "${v}" == "bar" ]
}

@test "${test} | Simple 1 | Always pass2" {

  [[ 0 -eq 0 ]]
}

@test "${test} | Simple 1 | Always pass3" {

  [[ 0 -eq 0 ]]
}
