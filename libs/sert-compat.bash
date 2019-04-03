#!/usr/bin/env bash

export KUBECTL="kube"
export sert_bats_workdir=${APP_ROOT}
export NAMESPACE=$(kube config get-contexts $(kube config current-context) --no-headers | awk '{print $5}')
