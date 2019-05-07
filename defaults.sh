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

# Default namespace to run test deployments in.
# If namespace rotation from sequential-helpers is enabled
# numerical values will be added to the NAMESPACE name for each bats file failure
export NAMESPACE=${NAMESPACE:-ivt}

export KUBE_APISERVER_PORT=${KUBE_APISERVER_PORT:-8001}

# Server / host part of url for kubernetes API server and ICP management ingress
export SERVER=${SERVER}

# The ICP Management ingress / router is located at port 8443 by default
export ROUTER_HTTPS_PORT=${ROUTER_HTTPS_PORT:-8443}

# Test images
## The small version of a HTTP image is typically nginx based on alpine, but others may work
export HTTP_IMAGE_SMALL=${HTTP_IMAGE_SMALL:-nginx:1.15.12-alpine}

## The fuller image expects to have some things like bash and some more command line tooling installed
export HTTP_IMAGE_FULL=${HTTP_IMAGE_FULL:-nginx:1.15.12}

## The default HTTP_IMAGE when not specified
export HTTP_IMAGE=${HTTP_IMAGE:-$HTTP_IMAGE_SMALL}

## Toolbox images can all point to the same image as long as the expected tools are there
export TOOLBOX_IMAGE_ALPINE=${TOOLBOX_IMAGE_ALPINE:-alpine:3.9.3}
export TOOLBOX_IMAGE_WGET=${TOOLBOX_IMAGE_WGET:-$TOOLBOX_IMAGE_ALPINE}

# Enable/disable test cases that cannot be detected
## The ability to expose services through NodePort is determined by firewalls in the
## network and hence cannot reliably be detected. This settings enable or disable
## tests that rely on NodePort. Set NODEPORT to enabled or disabled to indicate
## whether these tests can run
export NODEPORT=${NODEPORT:-enabled}

#####
# Settings for the sequential-helpers framework
export ON_SETUP_FAIL=${ON_SETUP_FAIL:-failfirst}
export ON_ASSERT_FAIL=${ON_ASSERT_FAIL:-skip_subsequent}
export ROTATE_NAMESPACE=${ROTATE_NAMESPACE:-false}
