[>/dev/null 2>&1; touch "!---$$"; : ]: # (Please keep this and the comment below)
<!---$$ >/dev/null 2>&1; rm -f "!---$$"
source Runbook.sh RUN "$@"
```
source Runbook.sh
```
----------------------------------------------------------------------------->
# Basic fixture

Steps are deliberately defined in non-alphabetical order.

```bash Step/zeta
    echo "step zeta"
```

```bash Step/alpha
    echo "step alpha"
```

```bash Task/hello
    echo "hello ${1:-world}"
```

```bash
#
# Print the runbook arguments.
#
# They are the arguments after -- on the command line.
#
Task/args () {
    echo "args: ${RB_CLI_ARGS[*]}"
}
```

```bash Task/dedupe
    rb-run Task/hello a
    rb-run Task/hello a
    rb-run Task/hello b
```

```bash helper
    echo "not a task"
```

<!---Please keep this comment-------------------------------------------------
```
rb-main "$@"
```
----------------------------------------------------------------------------->
