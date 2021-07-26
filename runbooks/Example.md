<!--- &>/dev/null : 'Please keep this comment' -------------------------------
source Runbook.sh RUN "$@"
```
source Runbook.sh
```
----------------------------------------------------------------------------->
# An Example Runbook
As an example, you might have these steps in your runbook for a maintenance
event:

#### On Thursday, 8 P.M., 2021-07-22

1. [ ] Announce in the engineering channel that maintenance is about to start.
2. [ ] [Set in-app message] for the maintenance.
3. [ ] Stop the service:
```bash
Task/Stop-Important-Service () {
    echo "Stopping service ..."
    Runbook/confirm-continue-task
    echo "Important service stopped!"
}
```
4. [ ] [Take a snapshot] of the DB.
5. [ ] Run the maintenance script:
```bash
Task/Run-Maintenance-Script () {
    Runbook/confirm-continue-task
    echo "Doing real work ..."
    local i=0
    while (( i < 7 )); do
        echo -n .;  sleep 1
        (( ++i ))
    done
    echo
    echo "All done!"
}
```
6. [ ] Start the service back up:
```bash
Task/Start-Important-Service () {
    Runbook/confirm-continue-task
    echo "Starting the service back up..."
    echo "Service started!"
}
```
7. [ ] [Check] that things are still working.
8. [ ] Notify in the engineering channel that the maintenance is now over.

[Set in-app message]: # (link here)
[Take a snapshot]: # (link here)
[Check]: # (link here)

<!---Please keep this comment-------------------------------------------------
```
rb-main "$@"
```
----------------------------------------------------------------------------->
