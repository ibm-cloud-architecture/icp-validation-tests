#!/usr/bin/env bats

load ../../helpers
load ${sert_bats_workdir}/framework.bash

@test "Group 2 | Simple 2 | Always pass1" {

  [[ 0 -eq 0 ]]
}

@test "Group 2 | Simple 2 | Always pass2" {

  [[ 0 -eq 0 ]]
}
@test "Group 2 | Simple 2 | Always pass3" {

  [[ 0 -eq 0 ]]
}
