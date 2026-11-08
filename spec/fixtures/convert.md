[>/dev/null 2>&1; touch "!---$$"; : ]: # (Please keep this and the comment below)
<!---$$ >/dev/null 2>&1; rm -f "!---$$"
source Runbook.sh RUN "$@"
```
source Runbook.sh
```
----------------------------------------------------------------------------->
# Conversion fixture

Some prose.

```bash
TOP_LEVEL=1
```

```bash brace-func () {
    echo brace
```

```bash subshell-func () (
    echo subshell
```

```bash no-bracket-func
    echo none
```

```bash function kw-func
    echo kw
```

```bash Step  # becomes Step/1
    echo one
```

```bash Step
    echo two
```

```sh
echo "sh fence"
```

~~~bash
echo "tilde fence"
~~~

````bash
echo "four backticks"
````

<!---Please keep this comment-------------------------------------------------
```
rb-main "$@"
```
----------------------------------------------------------------------------->
