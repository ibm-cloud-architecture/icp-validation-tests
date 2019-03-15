#!/usr/bin/env bats

load ../../helpers
load ${sert_bats_workdir}/framework.bash

function create_environment() {
  # This is where we create environment

  return 1
}

function destroy_environment() {
  return 0
}
@test "Fail Setup | Simple 1 | Always pass1" {

  [[ 0 -eq 0 ]]
}

@test "Fail Setup | Simple 1 | Always pass2" {

  [[ 0 -eq 0 ]]
}
@test "Fail Setup | Simple 1 | Always pass3" {

  [[ 0 -eq 0 ]]
}
