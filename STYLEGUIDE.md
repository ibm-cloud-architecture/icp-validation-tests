# Tests

Use bats builtin functionality and framework capability as much as possible

## BATS builtins

### run

Prepending `run` to any command will automatically make three variables available to you after the command is complete. `$output`, `$lines` and `$status`
- `$output` is the whole output of the command and you can use it to test for occurance of a word or word group anywhere in the output. For example `[[ "$output" =~ "Running" ]]`
- `$lines` is a bash array of each line of the output. So line 1 of the output is `${lines[0]}`, line 2 is `${lines[1]}`, etc. So if the exact occurance is imporant you can check with this, for example `[[ "${lines[0]}" == "Usage:" ]]`
- `$status` is the exit code of whatever command was run. NOTE: If you intend to use pipes you must put this into a `bash -c`, so for example

```
@test "Test that the pod is running" {
    run bash -c "kube get pods --no-headers | grep mypod"
    [[ "${lines[0]}" =~ Running ]]
}
```

## Framework Helpers


```
create_environment() {

}

environment_ready() {

}

destroy_environment() {

}

@test "mytest" {
  run do something
  assert_or_bail "[[ '$output' =~ 'something' ]]"
}
```
