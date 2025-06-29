[>/dev/null 2>&1; touch "!---$$"; : ]: # (Please keep this and the comment below)
<!---$$ >/dev/null 2>&1; rm -f "!---$$"
source Runbook.sh RUN "$@"
```
source Runbook.sh
```
----------------------------------------------------------------------------->
# Runbook.md

**Runbook.md** is a hack to create Bash executable [runbooks] in Markdown; it
can also be used to write Bash [literate programs] or just executable Markdown
documents in general. **Runbook.md** makes your actionable runbooks executable,
literally.

Markdown documents created with **Runbook.md** `source` its opinionated script
([Runbook.sh](Runbook.sh)), which provides error reporting, runbook logging,
selective task execution, ... etc. 

[runbooks]: https://wa.aws.amazon.com/wellarchitected/2020-07-02T19-33-23/wat.concept.runbook.en.html
[literate programs]: https://en.wikipedia.org/wiki/Literate_programming

## Features
- Error reporting includes stack traces back to the correct lines in the
  Markdown document.
- Runbook logging includes both normal output logs, as well as, detailed
  trace logs with all command expansions for ease of debugging and auditing.
- Organize your runbook with task functions, which are either discrete steps
  that can be executed sequentially and selectively, or are tasks that can be
  invoked individually in a specific order.

## Installation and Usage
1. Fork this repo.
2. Start writing your runbook in Markdown! You can put it in the `runbooks/`
   folder, in which there's an [example](runbooks/Example.md) runbook to get
   you started.

   You can also create a new, or decorate an existing, Markdown file to be
   executable by **Runbook.md** by running this command:

       $ ./Runbook.sh -x myrunbook.md

   which will add the HTML header and footer comments to the specified file
   and will make it executable.
    
3. To execute a runbook, do it from the root of the repo. You can either run it
   with Bash explicitly:

       $ bash runbooks/Example.md

   Or, if you make the runbook file executable, and you are running Bash as your
   interactive shell, then most likely you can just run it directly:

       $ runbooks/Example.md  # (pass -h to see help)

Don't want to fork and clone a repo? No problem. You can "install" **Runbook.md**
by simply downloading and saving [Runbook.sh](Runbook.sh) to a directory listed
in your `PATH` environment variable. E.g.,:

```bash
read -rp "Install the latest Runbook.md (Y/n)? "
case ${REPLY,,} in
  y|yes)
    url=https://raw.githubusercontent.com/kjkuan/Runbook.md/main/Runbook.sh
    curl -fSs "$url" | sudo tee /usr/local/bin/Runbook.sh >/dev/null
    ;;
  *) echo "Okay, take your time~" ;;
esac
```

Now as long as your Markdown file has the header and footer comment sections as
in the [Example.md] runbook, it can be executed as described above, no matter
where it's located.

[Example.md]: https://raw.githubusercontent.com/kjkuan/Runbook.md/main/runbooks/Example.md

> **Hint**: Eating our own dogfood, if you `git clone` this repo, you can simply
> execute this [README.md](README.md) file with Bash from the root of the repo
> to install **Runbook.md**, like so:  `bash ./README.md`


## How Your Runbook Will be Executed
Your runbook will be run with `set -eEo pipefail` as well as `shopt -s
inherit_errexit`.  You should know what that entails, and write your Bash code
accordingly.

Code sections fenced by triple backquotes starting at the *first* column, like
this:

    ```bash
    echo "Hello Runbook.md"
    echo "Start Time: $(date)"
    ```
will be executed as Bash commands in the shell process of the runbook, in the
order they appear in it. You are, of course, free to define functions or
`source` shell libraries, ... etc, or even run arbitrary commands in such
fenced code; however, it's recommended to do any actual work of a runbook in
task functions rather than directly in the top level of the document.

At the end of the runbook, Bash functions defined *directly* in the runbook,
and whose names starting with `Step/` (configurable), will be executed *in the
order they appear in the runbook* as well. Functions whose names starting with
`Task/` won't be executed unless they are selected for execution via a CLI
option. This allows you to organize your runbook as a single workflow of
*steps*, but also lets you define *tasks* that can be invoked individually.
Logging, by default, also starts when **Runbook.md** starts executing task
functions.

For example, here what defining a step and a task in a runbook looks like:

    This is a step:

    ```bash
    Step/greeting () {
        echo "Hello World"
    }
    ```

    This is a task:

    ```bash
    Task/bye () {
      echo "Good Bye~"
    }
    ```

> **NOTE**: Step functions, which are also task functions, must be defined
> in the runbook file directly. That is, they cannot be defined else where and
> then `source`d into the runbook. Doing so currently will mess up the task
> execution order.  This restriction might be lifted in the future.

Alternatively, you can start a function declaration in the same line as the
<code>```bash</code> marker and then omit the closing bracket (`}`):

    ```bash my-func () {
        echo "This is $FUNCNAME"
    ```

In this form, the opening bracket (`{`) of the function declaration determines the
kind of compound command (`(...)` or `{ ... }`) to be used as the function body,
and is optional (defaults to `{` if omitted). Therefore, the example above can
be written more succinctly as:

    ```bash my-func
        echo "This is $FUNCNAME"
    ```

Or, if you prefer to spell out `function` explicitly:

    ```bash function my-func
        echo "This is $FUNCNAME"
    ```

And, **Runbook.md** will automatically wrap the fenced code block within a
function whose name is taken from what comes after <code>```bash</code>.

Finally, as a special case in this form, if you name your function, `Step`, then
it will be wrapped in a step function that is automatically numbered, starting
from 1, and gets incremented by 1 for each `Step`:

    ```bash Step  # -> 'Step/1 () {'
        echo "Step ${FUNCNAME#*/}"
    ```

    ```bash Step  # -> 'Step/2 () {'
        echo "Step ${FUNCNAME#*/}"
    ```

    ...

This can be a cleaner way to show your code without the clutter of a function
declaration.


## Executing Runbook Steps and/or Tasks
You can list the steps of your runbook by running it with the `-ls` option:

    $ ./runbooks/Example.md -ls
    1  Step/1
    2  Step/2
    3  Step/last

To list the tasks, run it with the `-lt` option:

    $ ./runbooks/Example.md -lt
    Task/Check-Service-Status
    Task/Page-2nd-level-on-call

Run all the steps:

    $ ./runbooks/Example.md -s

Run from Step 2:

    $ ./runbooks/Example.md -s 2-

Run a specific task:

    $ ./runbooks/Example.md -t Task/Page-2nd-level-on-call

As a shortcut for running a single task, you can omit the `Task/` prefix if
neither `-s` nor `-t` are specified:

    $ ./runbooks/Example.md Page-2nd-level-on-call


## Tracking Task / Step Dependencies
To avoid repeating tasks or steps that have been executed, **Runbook.md**
by default keeps track of executed tasks for you when a task / step is executed.
You can also explicitly invoke any task / step functions with the `rb-run`
command to enable dependency tracking. For example,


    rb-run Task/dependency_1  # runs the task
    rb-run Task/dependency_1  # task won't be executed since it's been run by rb-run


Note that task executions are tracked by the task / step name and their
arguments. For example,


    rb-run Task/dependency_1 arg1  # runs the task with arg1
    rb-run Task/dependency_1 arg2  # runs the task with arg2 since the task + argument combination hasn't been run.
    rb-run Task/dependency_1 arg1  # won't run the task since the command "Task/dependency_1 arg1" has been run.



## See also the [FAQ](FAQ.md)

## Other Similar Tools
- [Blaze](https://github.com/0atman/blaze)
- [lit](https://github.com/vijithassar/lit)
- [mdsh](https://github.com/bashup/mdsh)
- [Babel](https://orgmode.org/worg/org-contrib/babel/)
- [Runbook](https://github.com/braintree/runbook)


## Contributing
Please open issues to discuss about questions / bug reports / feature requests.
Pull requests are welcome. For major change, please open an issue first to
discuss what you would like to change.

<!---Please keep this comment-------------------------------------------------
```
rb-main "$@"
```
----------------------------------------------------------------------------->
