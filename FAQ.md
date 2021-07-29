# FAQ

## Q: Why reading from STDIN no longer works?
## Answer:
When executing a runbook, the standard input of your runbook process (bash) is
used for reading the runbook script generated from the Markdown document; therefore,
reading from STDIN would actually read in parts of the runbook itself!

To work around that, you can read from `/dev/tty` if you are running the runbook
from an interactive console. If you need to redirect your runbook's STDIN, consider
reading from a file on disk instead; you can pass in the file path as a CLI argument
(see answer to the next question).


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
