#!/usr/bin/env bats

@test "pass this" {
  [[ 1 -eq 1 ]]
}

@test "skip that" {
  skip "that"
}

@test "fail the other" {
  [[ 1 -eq 0 ]]
}
