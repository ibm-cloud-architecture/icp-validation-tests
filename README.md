
[![Build Status](https://travis.ibm.com/IBMPrivateCloud/icp-sert-bats.svg?token=9eXqaUMAsuqFszj7yyKB&branch=master)](https://travis.ibm.com/IBMPrivateCloud/icp-sert-bats)

# Integration Tests

Integration tests provide end-to-end testing of ICP.

While unit tests verify the code is working as expected by relying on mocks and
artificially created fixtures, integration tests actually use real ICP environment through the kubectl CLI.

Note that integration tests do **NOT** replace unit tests.

As a rule of thumb, code should be tested thoroughly with unit tests.
Integration tests on the other hand are meant to test a specific feature end
to end.

Integration tests are written in *bash* using the
[bats](https://github.com/sstephenson/bats) framework.

and the License info of *bats* was: https://github.com/sstephenson/bats/blob/master/LICENSE

How to install *bats*:
```
$ git clone https://github.com/hchenxa/bats.git
$ cd bats
$ ./install.sh /usr/local
```


## Running integration tests
There are two method to run the tests:

A. you can run integration tests directly on your host, for example, ICP master:

```
$ git clone git@github.ibm.com:IBMPrivateCloud/icp-sert-bats.git
$ cd icp-sert-bats/
$ ./run.sh
```

This will run all cases.

And the result like below:
<img src="https://github.ibm.com/IBMPrivateCloud/icp-infrastructure-bats/blob/master/gif/all_cases.gif"/>
Note: testui cases can't run directly on your ppc64le and s390x platform.

B. you can run the tests remotely:

 1). Create your x86_64 machine which can be communicate with ICP cluster.

 2). Install `kubectl` command in this machine, Expose the ACCESS_IP and ROUTER_HTTPS_PORT to point to your ICP cluster access IP:port

 3). ` git clone git@github.ibm.com:IBMPrivateCloud/icp-sert-bats.git` in the x86_64 machine, now support x86_64, ppc64le and s390x platform.

    if your cluster is x86_64 cluster:

       run ./run.sh in x86 machine.

    if your cluster is ppc64le cluster:

       run ARCH=ppc64le ./run.sh in x86 machine

    if your cluster is s390x cluster:

      run ARCH=s390x ./run.sh in x86 machine

This tool have some options during run the tests:

a. And you can run part of cases by:
```
$ run.sh --cases "case1,case2,case3"
```

This will run the cases case1,case2,case3 and the result like below:
<img src="https://github.ibm.com/IBMPrivateCloud/icp-infrastructure-bats/blob/master/gif/cases.gif"/>


b. Also you can run the cases group by:
```
$ run.sh --groups "group1,group2,group3"
```

this will run the cases under group group1,group2,group3 and the result like below:
<img src="https://github.ibm.com/IBMPrivateCloud/icp-infrastructure-bats/blob/master/gif/groups_cases.gif"/>


In order to do that, you will need to setup a full development environment plus
[bats](https://github.com/sstephenson/bats#installing-bats-from-source)


c. Run UI cases:

 1. Run UI cases by group:

 Before running scripts, set envirnoment variable `DISPLAY=:99`

 ```
 $ export DISPLAY=:99
 $ ./run.sh -g testui
 ```
d. Skip a group to run test.

```
$ ./run.sh -ng testui

```

e. Expose the test result use xml format:

The test framework support to expose the test result using xml format which used to publised on allure.
before running the scrips, set the environment variable `OUTPUT_FORMAT=junit`.

After the cases finished, the report will placed under ./report.

Execute the `allure generate report` to generate the allure report. to get the allure, please download from https://github.com/allure-framework/allure2

Then you can view the allure report by `allure open ./allure-report` and this command will start up a http service.

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

[helper functions](https://github.ibm.com/IBMPrivateCloud/icp-infrastructure-bats/blob/master/helpers.bash)

```
# This will load the helpers.
load helpers

@test "this is a simple test" {
    # this was the simple test:
    echo "this was the simple test"
    [[ "$?" -eq 0 ]]
}
```


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

### ICP-SERT-BATS Special
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
