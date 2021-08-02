# FAQ

## Q: How can I see the resulting runbook script without executing anything in a runbook?
## Answer:
If you set the `RB_DUMP` environment variable to a non-empty string, then,
instead of executing the runbook, **Runbook.md** will simply dump the generated
Bash script to standard output. For example, you can get the generated Bash
script with source lines numbered with:

    $ RB_DUMP=1 ./my-runbook | nl -ba

## Q: I've added `set -x` in my runbook, but I'm not seeing its output when I run it.
## Answer:
**Runbook.md** already does `set -x` for you and redirects its output to the
trace log file, which by default is saved in `./log`. Additionally, you can
control when **Runbook.md** starts logging your runbook execution. By default,
logging starts when tasks run. If you specify the `--log-from-start` CLI
option, it will log from the start of you runbook.

## Q: How can I pass CLI arguments to my runbook, or to a specific task?
## Answer:
When a runbook is invoked, any remaining CLI arguments not consumed by
**Runbook.md** are passed on to your runnbook:

    $ ./my-runbook -t 1 arg1 arg2

In the example above, `-t 1` will be consumed by **Runbook.md**, and then both
`arg1` and `arg2` will be passed on to the runbook as `$1` and `$2`
respectively.  Further more, `$0` of your runbook, in this case, will be set to
the absolute path of `my-runbook`.

In order for a task function to access the CLI args easily, the `RB_CLI_ARGS`
array can be used. E.g., you can do: `set -- "${RB_CLI_ARGS[@]}"` inside your
task function to set the CLI args passed to your runbook script as positional
args of the function.

## Q: Something's not right when I set up my own EXIT or ERR trap in my runbook!
## Answer:
**Runbook.md** relies on both the `EXIT` and the `ERR` traps it sets up for
proper error reporting and command logging. If you need to run commands on
script exit, you can add them to the `RB_EXIT_CMDS` array, and they will be
executed by **Runbook.md** when your runbook exits. For example:

    RB_EXIT_CMDS+=('echo "End of runbook, ${0##*/}. Bye!"')

## Q: Why do I see this giant string that looks like my runbook source in the OS' process list when I execute my runbook?
## Answer:
By default **Runbook.md** execute your runbook by passing the generated Bash
script as the CLI argument to `bash -c`. This avoids having to save a temporary
file, or using a named pipe / process susbstitution, or other similar tricks,
which also tend to make the source file name look strange in error reporting.

However, if you'd like to prevent the source code of your runbook script from
showing up in the process list, there's an alternate runbook execution mode
that you can trigger by setting the `RB_FROM_STDIN` environment variable to a
non-empty string. In this mode, your runbook will be executed by feeding it to
Bash via the runbook process' standard input.  The caveat with this is that
your runbook's STDIN no longer works as expected. To work around this problem,
you can redirect your command's STDIN from the file descriptor stored in the
`RB_STDIN` environment variable. E.g.,

    read -rp "Enter something: " <&$RB_STDIN

Or, with `read` you can also use `-u`:

    read -u $RB_STDIN -rp "Enter something: "


## Q: How can I execute selected tasks in the order specified with `-t`?
## Answer:
You can't. Currently, **Runbook.md** always execute tasks in the order they are
defined directly in the runbook. This means even if you specify `-t 3,2,1`
in the CLI, the tasks will still be executed as task 1, 2, and 3.

To work around this, you can run each task as a separate CLI invocation. E.g.,

    $ ./my-runbook -t 3
    $ ./my-runbook -t 2
    $ ./my-runbook -t 1
