#!/usr/bin/env bash

source icp-kube-functions.bash
#_skip_destroy="true"
if [[ $(type -t run_as) && ! "$_skip_destroy" == "true" ]]; then
      echo "DESTROY"
    fi
#run_as -u me -n myself echo "foo bar baz -n someone"
#echo $?