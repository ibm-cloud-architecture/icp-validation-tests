# Global settings

# Do individual bats runs per group,
# or all groups in a single run
export GROUP_RUNS=${GROUP_RUNS:-false}

# Output format for bats. Can be 'pretty' or 'tap'
export BATS_OUTPUT=${BATS_OUTPUT:-pretty}

# Location of test suites
export TEST_SUITE_ROOT=${TEST_SUITE_ROOT:-${APP_ROOT}/suites}

# Setup even if not explicitly declared in *.bats cases
export IMPLICIT_CAPABILITIES=( )

# If disabled the assumption is that everything
# kubectl, namespace, etc is setup beforehand
export PREINSTALL_TEST_PREREQS=${PREINSTALL_TEST_PREREQS:-true}


#####
# Kubernetes and cluster defaults

# Default namespace to run test deployments in
export NAMESPACE=${NAMESPACE:-ivt}

export KUBE_APISERVER_PORT=${KUBE_APISERVER_PORT:-8001}

export SERVER=${SERVER}


#####
# Settings for the sequential-helpers framework
export ON_SETUP_FAIL=${ON_SETUP_FAIL:-failfirst}
export ROTATE_NAMESPACE=${ROTATE_NAMESPACE:-on_any_fail}
