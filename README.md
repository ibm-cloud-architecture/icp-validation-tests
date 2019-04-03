
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
- `SERVER` sets the `IP` or `Hostname` of the cluster access (Master IP, VIP or  LoadBalancer). If `SERVER` is not set, an attempt will be made to extract this from `kubectl` if the user is already authenticated.
- `KUBECTL` sets the path of `kubectl` command. Defaults to any available `kubectl` in path if not set. If no `kubectl` is available `kubectl` will be downloaded from the ICP cluster and placed in `/usr/local/bin`
- `ROUTER_HTTPS_PORT` sets the port for the management ingress, where the dashboard and ICP services can be found. Defaults to `8443` if not set
- `USERNAME` sets the admin username to use when connecting to the cluster. Defaults to `admin` if not set
- `PASSWORD` sets the admin password to use when connecting to the cluster. Defaults to `admin` if not set
- `KUBE_APISERVER_PORT` sets the Kubernetes API Server port. Defaults to `8001` if not set
- `IPSEC_ENABLED` set to "true" to enable IPSEC tests on the environment. IPSEC cannot be detected, so IPSEC tests will not run unless explicitly enabled

### Example use

```
export SERVER="10.0.0.10"
export PASSWORD="MyVerySafePassword"
./run.sh
```

# Writing integration tests


There's a number of helper functions available.

## Sequential helper
[sequential helpers](https://github.com/ibm-cloud-architecture/icp-validation-tests/blob/master/libs/sequential-helpers.bash)
This is a framework specifically design to help with tests where there is a given relationship between the different test cases in a single test file.

### Applicability

You can easily indicate the applicability of all the tests in a single bats file by defining a function called `applicable()` which returns `0` (true) if the environment is applicable for the tests and `1` (false) if not.
If the `applicable()` function returns `0` in a given environment all tests defined in that file will automatically be skipped with the message `Not applicable in this environment`.


Example use
```
#!/usr/bin/env bats

load ${APP_ROOT}/libs/sequential-helpers.bash

function applicable() {

  if [[ "${API_VERSIONS[@]}" =~ "metrics.k8s.io" ]]; then
    return 0
  else
    return 1
  fi
}

@test "usual test definition" {
  run something as you normally would, but will only run if applicable
  [[ "foo" == "bar" ]]
}
```

```
#!/usr/bin/env bats

load ${APP_ROOT}/libs/sequential-helpers.bash

function applicable() {
  n=$(kubectl -n kube-system get deployments | grep myfeaturedeployment )
  if [[ "$n" =~ "myfeaturedeployment" ]]; then
    return 0
  else
    return 1
  fi
}

@test "usual test definition" {
  run something as you normally would, but will only run if applicable
  [[ "foo" == "bar" ]]
}
```

### Skip or fail all tests when setup prerequisites are not met

A fairly commmon scenario is to create some environment that tests will be run against. This could be create a `deployment` that is scaled up, down, connected to, etc.... However, if the initial creation of the deployment is not successful there is no need to attempt to run all the test cases in the bats file.

To address this, you can simply define a `create_environment()` function to define how the environment should be created before start running tests. A `destroy_environment` function can be defined to clean up the environment after all test cases have run. Optionally you can also define an `environment_ready` function to determine when the environment is ready to start accepting test cases.

If `create_environment()` returns a status of `1` all tests in the file will be skipped or failed depending on setting. This is configured via the global `ON_SETUP_FAIL` variable which can be set to `skip` which will make all tests `skip` with message `Environment setup failed`, `fail` which will automatically fail all tests with message `Environment setup failed` or `failfirst` (default) which will fail the first test case and skip the remainding.


The `environment_ready` function will be retried at regular intervals and if does not return a status `0` within `ENV_SETUP_TIMEOUT` seconds all tests will be `skipped` or `failed` as with `create_environment` based on the `ON_SETUP_FAIL` setting, but with message `Timed out waiting for environment to become ready`

Example

```
#!/usr/bin/env bats
# Override some defaults
ON_SETUP_FAIL="fail" # We want all test cases to fail if environment setup fails
ENV_READY_SLEEP="2" # Seconds between each attempt to run environment_ready function
ENV_READY_TIMEOUT="60" # Seconds before timing out waiting for environment to become ready

load ${APP_ROOT}/libs/sequential-helpers.bash

create_environment() {
  kube create -f ${TEST_SUITE_ROOT}/mytest/templates/myapp.yaml
  return $?
}

environment_ready() {
  status=$(kube get pods -l run=nginx,test=deployment --no-headers | awk '{print $3}')
  if [[ "$status" == "Running" ]]; then
    return 0
  else
    return 1
  fi
}

destroy_environment() {
  kube delete -f ${TEST_SUITE_ROOT}/mytest/templates/myapp.yaml
}



@test "usual test definition" {
  run something as you normally would
  [[ "foo" == "bar" ]]
}
```


### Leave failed deployments intact
Sometimes you may want failed tests to be left intact so the environment can be used for debugging at a later point. Where the `create_environment` and `destroy_environment` methods are used, you can can set this behaviour via the `ROTATE_NAMESPACE` variable. This variable can be set globally or optionally overwritten per test file.
When `ROTATE_NAMESPACE` is enabled, a failure will cause the `destroy_environment` not to be called, a new namespace called `NAMESPACE`N where `N` is a number series starting at 1 for the first failed test.

`ROTATE_NAMESPACE` can be set to `on_setup_fail` which triggers this behaviour if `create_environment` or `environment_ready` fails, `on_test_fail` which triggers this behaviour if `fail_subsequent` or `skip_subsequent` are called, and `on_any_fail` which is a combination of these.



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
