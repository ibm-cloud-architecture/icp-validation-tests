#!/usr/bin/env bats
CAPABILITIES=("kubectl")

@test "pass this" {
  [[ 1 -eq 1 ]]
}

@test "pass that" {
  [[ 1 -eq 1 ]]
}

@test "pass the other" {
  [[ 1 -eq 1 ]]
}
