# shellcheck shell=bash

# Make sure `source Runbook.sh` in the runbook header picks up this repo's copy.
PATH="$SHELLSPEC_PROJECT_ROOT:$PATH"

# Plain, predictable output: no ANSI colors, no log files unless a test asks.
export NO_COLOR=1
export RB_LOG_DIR=
unset RB_LOG_FROM_START RB_DUMP RB_STEP_REGEX RB_TASK_REGEX

FIXTURES="$SHELLSPEC_PROJECT_ROOT/spec/fixtures"

# Run a fixture runbook from a scratch working directory (the runbook header
# creates and removes a temporary file in $PWD).
runbook() {
    local name=$1; shift
    (cd "$SHELLSPEC_TMPBASE" && bash "$FIXTURES/$name" "$@")
}

# Print the generated Bash script for a fixture without running it.
dump_runbook() {
    RB_DUMP=1 runbook "$@"
}

# Line number of the first line in a fixture that contains the given text.
line_of() {
    grep -n -F -m1 -- "$2" "$FIXTURES/$1" | cut -d: -f1
}

# Fresh, empty directory under ShellSpec's temp dir.
make_tmpdir() {
    mktemp -d "$SHELLSPEC_TMPBASE/rb.XXXXXX"
}
