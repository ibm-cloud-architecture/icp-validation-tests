#!/usr/bin/env bash

source icp-kube-functions.bash

run_as -u me -n myself echo "foo bar baz -n someone"
echo $?
