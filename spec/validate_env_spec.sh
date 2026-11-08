# shellcheck shell=bash

Describe 'rb-validate-env'
  setup() { unset TARGET_HOST TARGET_PORT; }
  Before setup

  It 'runs before the steps when defined'
    export TARGET_HOST=db1
    When run runbook env.md -q
    The status should be success
    The output should eq "validating env
step host: db1"
  End

  It 'runs before tasks selected with -t'
    export TARGET_HOST=db1
    When run runbook env.md -q -t Task/show-host
    The status should be success
    The output should eq "validating env
task host: db1"
  End

  It 'stops the runbook with rb-die before running anything'
    When run runbook env.md
    The status should be failure
    The output should eq 'validating env'
    The stderr should eq 'Runbook.md: TARGET_HOST is not set!'
  End

  It 'stops the runbook with a stack trace on any other failure'
    export TARGET_HOST=db1 TARGET_PORT=http
    When run runbook env.md
    The status should be failure
    The output should eq 'validating env'
    The stderr should include "env.md, line $(line_of env.md '=~ ^[0-9]+$'), in rb-validate-env ():"
  End

  It 'runs before logging starts, so a failure leaves no logs'
    with_logdir() { RB_LOG_DIR=$LOGDIR runbook "$@"; }
    LOGDIR=$(make_tmpdir)/log
    When run with_logdir env.md
    The status should be failure
    The output should eq 'validating env'
    The stderr should be present
    The path "$LOGDIR" should not be exist
  End

  Parameters
    -ls
    -lt
    '-h -ls -lt'
    '-h show-host'
  End

  It "is not called for '$1'"
    # shellcheck disable=SC2086
    When run runbook env.md $1
    The status should be success
    The output should not include 'validating env'
  End
End
