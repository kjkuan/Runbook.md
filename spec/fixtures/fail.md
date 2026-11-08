[>/dev/null 2>&1; touch "!---$$"; : ]: # (Please keep this and the comment below)
<!---$$ >/dev/null 2>&1; rm -f "!---$$"
source Runbook.sh RUN "$@"
```
source Runbook.sh
```
----------------------------------------------------------------------------->
# Failing fixture

```bash Step/ok
    echo "ok"
```

```bash Step/boom
    echo "before"
    false  # FAIL HERE
    echo "after"
```

```bash Step/never
    echo "never"
```

<!---Please keep this comment-------------------------------------------------
```
rb-main "$@"
```
----------------------------------------------------------------------------->
