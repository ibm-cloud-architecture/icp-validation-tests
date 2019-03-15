#!/usr/bin/env bats
test="Applicability"
load ../../helpers
load ${sert_bats_workdir}/framework.bash

function create_environment() {
  # This is where we create environment
  return 0
}

function applicable() {
  # kubectl -n kube-system get pods | grep elasticsearch
  return 1
}

@test "${test} | Simple 1 | Always pass1" {

  [[ 0 -eq 0 ]]
}

@test "${test} | Simple 1 | Fail this one" {
  v="foo"

  [ "${v}" == "bar" ]
}

@test "${test} | Simple 1 | Always pass2" {

  [[ 0 -eq 0 ]]
}

@test "${test} | Simple 1 | Always pass3" {

  [[ 0 -eq 0 ]]
}
