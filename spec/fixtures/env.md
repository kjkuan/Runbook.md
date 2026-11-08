[>/dev/null 2>&1; touch "!---$$"; : ]: # (Please keep this and the comment below)
<!---$$ >/dev/null 2>&1; rm -f "!---$$"
source Runbook.sh RUN "$@"
```
source Runbook.sh
```
----------------------------------------------------------------------------->
# Env validation fixture

```bash
# Expects:
#   TARGET_HOST - host to run on
#   TARGET_PORT - optional, a port number
rb-validate-env () {
    echo "validating env"
    [[ ${TARGET_HOST:-} ]] || rb-die "TARGET_HOST is not set!"
    [[ ${TARGET_PORT:-80} =~ ^[0-9]+$ ]]
}
```

```bash Step/use-host
    echo "step host: $TARGET_HOST"
```

```bash Task/show-host
    echo "task host: $TARGET_HOST"
```

<!---Please keep this comment-------------------------------------------------
```
rb-main "$@"
```
----------------------------------------------------------------------------->
