
# ICP Validation tests

Integration tests provide end-to-end testing of ICP.

While unit tests verify the code is working as expected by relying on mocks and
artificially created fixtures, integration tests actually use real ICP environment through the kubectl CLI.

Note that integration tests do **NOT** replace unit tests.

As a rule of thumb, code should be tested thoroughly with unit tests.
Integration tests on the other hand are meant to test a specific feature end
to end.

Integration tests are written in *bash* using the
[bats](https://github.com/bats-core/bats-core) framework.


## Running tests

```
$ git clone https://github.com/ibm-cloud-architecture/icp-validation-tests.git
$ cd icp-validation/
$ ./run.sh
```

## Prerequisites

The following are are used and required by these scripts

- bash
- jq
- grep
- awk
- git
- bats-core

### Install prereqs on Mac

- brew install jq
- brew install bash
- brew install coreutils
- brew install bats
- brew install git

## Environment variables

There are several variables you can set to modify the test suite

- `NAMESPACE` sets the namespace to create test pods in. This namespace will be created and deleted by the test framework. Defaults to `ivt` if not set
- `ACCESS_IP` sets the `IP` or `Hostname` of the cluster access (Master IP, VIP or  LoadBalancer). If `ACCESS_IP` is not set, an attempt will be made to extract this from `kubectl` if the user is already authenticated.
- `KUBECTL` sets the path of `kubectl` command. Defaults to any available `kubectl` in path if not set. If no `kubectl` is available `kubectl` will be downloaded from the ICP cluster and placed in `/usr/local/bin`
- `ROUTER_HTTPS_PORT` sets the port for the management ingress, where the dashboard and ICP services can be found. Defaults to `8443` if not set
- `CLUSTERNAME` sets the name of the cluster. Defaults to `mycluster` if not set
- `USERNAME` sets the admin username to use when connecting to the cluster. Defaults to `admin` if not set
- `PASSWORD` sets the admin password to use when connecting to the cluster. Defaults to `admin` if not set
- `KUBE_APISERVER_PORT` sets the Kubernetes API Server port. Defaults to `8001` if not set
- `IPSEC_ENABLED` set to "true" to enable IPSEC tests on the environment. IPSEC cannot be detected, so IPSEC tests will not run unless explicitly enabled

### Example use

```
export ACCESS_IP="10.0.0.10"
export PASSWORD="MyVerySafePassword"
./run.sh
```

## Writing integration tests


There's a number of helper functions available.

[sequential helpers](https://github.com/ibm-cloud-architecture/icp-validation-tests/blob/master/libs/sequential-helpers.bash)
This introduces some useful functions for tests that have dependencies on environment (i.e. istio deployed), successful setup of a prerequisite environment (i.e. successful deployment of application to test), and successful execution of previous tests in the same bats file.

_applicable_

This function is used to determine if the tests in the current file should run. If `applicable` returns 1 all the tests in the current bats file will be skipped with the message `Not applicable in this environment`
Example use
```
#!/usr/bin/env bats

load ${APP_ROOT}/libs/sequential-helpers.bash

function applicable() {
  n=$(kubectl -n kube-system get pods | grep )
}
```

```
# This will load the helpers.
load endtoend-helper

@test "this is a simple test" {
    # this was the simple test:
    echo "this was the simple test"
    [[ "$?" -eq 0 ]]
}
```
## Functions available to tests

## Variables available to all tests

There are several global variables you can use to introspect on Bats tests

### BATS Special
- `$BATS_TEST_FILENAME` is the fully expanded path to the Bats test file.
- `$BATS_TEST_DIRNAME` is the directory in which the Bats test file is located.
- `$BATS_TEST_NAMES` is an array of function names for each test case.
- `$BATS_TEST_NAME` is the name of the function containing the current test case.
- `$BATS_TEST_DESCRIPTION` is the description of the current test case.
- `$BATS_TEST_NUMBER` is the (1-based) index of the current test case in the test file.
- `$BATS_TMPDIR` is the location to a directory that may be used to store temporary files.

### ICP-VALIDATION Special
- `$NAMESPACE` is the namespace to run tests against / in
- `$ARCH` is the processor architecture targeted for the tests

- `$K8S_SERVERVERSION_MAJOR` is the Kubernetes Server Major version
- `$K8S_SERVERVERSION_MINOR` is the Kubernetes Server Minor version
- `$K8S_SERVERVERSION_STR` is the Kubernetes Server gitVersion string

- `$K8S_CLIENTVERSION_MAJOR` is the kubectl Major version
- `$K8S_CLIENTVERSION_MINOR` is the kubectl Minor version
- `$K8S_CLIENTVERSION_STR` is the kubectl gitVersion string

- `$ICPVERSION_MAJOR` is the ICP platform Major version -- i.e. *2* in 2.1.0.3
- `$ICPVERSION_MINOR` is the ICP platform Minor version -- i.e. *1* in 2.1.0.3
- `$ICPVERSION_PATCH` is the ICP platform Patch version -- i.e. *0* in 2.1.0.3
- `$ICPVERSION_REV` is the ICP platform Revision version (if available) -- i.e. *3* in 2.1.0.3
- `$ICPVERSION_STR` is the ICP platform full version string
- `$API_VERSIONS` array of kubernetes api versions 


### Standard images to use

Since the test suite is expected to be run on both airgapped and non-airgapped environments,
it is desirable to limit the amount of images that are used, so as to limit the amount of
images that will need to be added to air gapped environments as a prerequisite to running the tests.

Suggested images to use:
- `nginx` -- where network functionality is required, i.e. requiring something to listen to a port
- `busybox` -- small lightweight image with most useful tools available
