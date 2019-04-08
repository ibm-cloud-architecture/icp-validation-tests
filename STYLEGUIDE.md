# Writing Tests

There are some practices to follow when adding tests to this project

## Detect applicability

All tests should be able to run in any environment without explicitly enabling and disabling tests.

To simplify this you can define a `applicable()` function in your test file, which will `return 0` if the tests in the bats file are applicable in the given environment, and `return 1` if the tests should be skipped in the given environment. Example

```
#!/usr/bin/env bats

load ${APP_ROOT}/libs/sequential-helpers.bash

applicable() {
  run kube -n kube-system get deployments
  if [[ "$output" =~ "my-feature-deployment" ]]; then
    # The tests in this file should run
    return 0
  else
    # The tests in this file are not applicable in this environment
    return 1
  fi
}
```

## Utilise existing functionality

Both bats and the overall framework has a number of global variables and and functions available. Please consult the list of available functionality before and during writing tests.

## BATS builtins

### run

Prepending `run` to any command will automatically make three variables available to you after the command is complete. `$output`, `$lines` and `$status`
- `$output` is the whole output of the command and you can use it to test for occurance of a word or word group anywhere in the output. For example `[[ "$output" =~ "Running" ]]`
- `$lines` is a bash array of each line of the output. So line 1 of the output is `${lines[0]}`, line 2 is `${lines[1]}`, etc. So if the exact occurance is imporant you can check with this, for example `[[ "${lines[0]}" == "Usage:" ]]`
- `$status` is the exit code of whatever command was run. NOTE: If you intend to use pipes you must put this into a `bash -c`, so for example

```
@test "Test that the pod is running" {
    run bash -c "kube get pods --no-headers -l app=myapp,test=mytest"
    [[ "${lines[0]}" =~ Running ]]
}
```

## Framework Helpers

### sequential-helpers

The file [libs/sequential-helpers.bash](libs/sequential-helpers.bash) defines some useful structures when there are external dependencies and/or sequential dependencies for the test cases defined in the file.

- `applicable()` is defined to declare how to determine if external dependencies are met. So for example test cases for Istio should not run in environments where Istio is not installed. So the `applicable()` function should define the necessary queries to determine if the tests cases are applicable and `return 0` if the test cases should run, and `return 1` if they should be skipped
- `create_environment()`, `environment_ready()`, `destroy_environment()` defines a framework for creating an environment that the test cases in the file are dependent on. For example if a bats file includes test cases to validate that a deployment can be scaled, updated, etc, the deployment to be acted upon is a dependency to be managed by the framework. Use `create_environment()` to define how the deployment is created, `environment_ready()` to define how to determine that the environment is ready to run tests against and `destroy_environment()` to define how the environment is cleaned up after all the test cases have completed. The framework will automatically deal with skipping or failing tests if environment setup fails, making sure environment is ready before attempting tests, timing out in an orderly fashion if environment does not become ready in a timely manner.
- `assert_or_bail` is a helper to "bail" the remainding test cases when an assertion fails. This is particularly useful for "end-to-end" type tests, where each test is dependent on the previous step having completed successfully.
- `skip_subsequent` can be run inside any test case to automatically skip any subseqent test cases
- `fail_subsequent` can be run inside any test case to automatically fail any subseqent test cases

Example

```
#!/usr/bin/env bats

create_environment() {
  run kube create -f ${TEST_SUITE_ROOT}/mytest/templates/mytest.yaml
  return $status
}

environment_ready() {
  run kube get pods -l app=myapp,test=mytest
  if [[ "$output" =~ "Running" ]];
    # Environment is ready
    return 0
  else
    # Environment is not ready yet
    return 1
  fi
}

destroy_environment() {
  kube delete -f ${TEST_SUITE_ROOT}/mytest/templates/mytest.yaml
}

@test "mytest | create user" {
  run create user command
  assert_or_bail "[[ '$output' =~ 'user created' ]]"
}

@test "mytest | new user can not do something" {
  run do something as new user
  assert_or_bail "[[ '$output' =~ 'Permission denied' ]]"
}

@test "mytest | new user can do something else"
  run do something else as new user
  assert_or_bail "[[ '$output' =~ 'something else' ]]"
```

# Extending the framework

Always write unit tests and make sure all unit tests pass before committing code.
