[&>/dev/null; touch "!---$$"; : ]: # (Please keep this and the comment below)
<!---$$ &>/dev/null; rm -f "!---$$"
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
- Organize your runbook with task functions, which are discrete steps
  that can be procedurally or selectively executed with a runbook.

## Installation and Usage
1. Fork this repo.
2. Start writing your runbook in Markdown! You can put it in the `runbooks/`
   folder, in which there's an [example](runbooks/Example.md) runbook to get you
   started.
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
and whose names starting with `Task/`, will be executed in the order they
appear in the runbook as well.  This allows you to define *tasks* or *steps* as
functions to be executed by the runbook. Logging, by default, also start when
**Runbook.md** start executing task functions.

> **NOTE**: Task functions (`Task/*`) must be defined in the runbook file
directly. That is, they cannot be defined else where and then `source`d into
the runbook. Doing so currently will mess up the task execution order.  This
restriction might be lifted in the future.

## See also the [FAQ](FAQ.md)

## Other Similar Tools
- [Blaze](https://github.com/0atman/blaze)
- [lit](https://github.com/vijithassar/lit)
- [mdsh](https://github.com/bashup/mdsh)
- [Babel](https://orgmode.org/worg/org-contrib/babel/)


## Contributing
Please open issues to discuss about questions / bug reports / feature requests.
Pull requests are welcome. For major change, please open an issue first to
discuss what you would like to change.

<!---Please keep this comment-------------------------------------------------
```
rb-main "$@"
```
----------------------------------------------------------------------------->
