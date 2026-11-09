[>/dev/null 2>&1; touch "!---$$"; : ]: # (Please keep this and the comment below)
<!---$$ >/dev/null 2>&1; rm -f "!---$$"
source Runbook.sh RUN "$@"
```
source Runbook.sh
```
----------------------------------------------------------------------------->
# Run summary fixture

```bash Step/one
    echo "one"
    rb-run Step/two
```

```bash Step/two
    echo "two"
```

```bash Step/three
    echo "three start"
    Runbook/confirm-continue-task
    echo "three end"
```

```bash Task/extra
    echo "extra"
```

<!---Please keep this comment-------------------------------------------------
```
rb-main "$@"
```
----------------------------------------------------------------------------->
