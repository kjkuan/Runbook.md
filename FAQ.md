# FAQ

## Q: How can I see the resulting runbook script without executing anything in a runbook?
## Answer:
If you set the `RB_DUMP` environment variable to a non-empty string, then, instead
of executing the runbook, **Runbook.md** will simply dump the generated Bash script
to standard output. For example, you can get the generated Bash script with source
lines numbered with:

    RB_DUMP=1 ./my-runbook | nl -ba

## Q: How can I pass CLI arguments to my runbook, or to a specific task?
## Answer:
When a runbook is invoked, any remaining CLI arguments not consumed by **Runbook.md**
are passed on to your runnbook:

    ./my-runbook -t 1 arg1 arg2

In the example above, `-t 1` will be consumed by **Runbook.md**, and then
both `arg1` and `arg2` will be passed on to the runbook as `$1` and `$2` respectively.
Further more, `$0` of your runbook, in this case, will be set to the absolute path of
`my-runbook`.

In order for a task function to access the CLI args easily, the `RB_CLI_ARGS` array
can be used. E.g., you can do: `set -- "${RB_CLI_ARGS[@]}"` inside your task function
to set the CLI args passed to your runbook script as positional args of the function.

## Q: Something's not right when I set up my own EXIT or ERR trap in my runbook!
## Answer:
**Runbook.md** relies on both the `EXIT` and the `ERR` traps it sets up for
proper error reporting and command logging. If you need to run commands on
script exit, you can add them to the `RB_EXIT_CMDS` array, and they will be
executed by **Runbook.md** when your runbook exits. For example:

    RB_EXIT_CMDS+=('echo "End of runbook, ${0##*/}. Bye!"')
