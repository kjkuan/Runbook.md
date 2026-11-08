# shellcheck shell=bash

Describe 'Task execution'
  Describe 'rb-run dependency tracking'
    It 'runs a task once per unique argument list'
      When run runbook basic.md -qq dedupe
      The status should be success
      The output should eq "hello a
hello b"
    End
  End

  Describe 'error handling'
    It 'stops at the failing step and exits non-zero'
      When run runbook fail.md
      The status should be failure
      The output should include 'ok'
      The output should include 'before'
      The output should not include 'after'
      The output should not include 'never'
      The stderr should include 'Stack trace'
    End

    It 'reports the failing line of the Markdown file'
      When run runbook fail.md
      The status should be failure
      The output should be present
      The stderr should include "fail.md, line $(line_of fail.md 'FAIL HERE'), in Step/boom ():"
      The stderr should include 'false  # FAIL HERE'
    End
  End

  Describe 'Runbook/confirm-continue-task'
    It 'continues on "y"'
      Data 'y'
      When run runbook confirm.md -q
      The status should be success
      The output should include 'end one'
      The output should include 'step two'
    End

    It 'skips the rest of the task on "s" and moves on'
      Data 's'
      When run runbook confirm.md -q
      The status should be success
      The output should include 'start one'
      The output should not include 'end one'
      The output should include 'step two'
    End

    It 'quits on "q"'
      Data 'q'
      When run runbook confirm.md -q
      The output should include 'start one'
      The output should not include 'end one'
      The output should not include 'step two'
    End

    It 'does not prompt with -y'
      When run runbook confirm.md -q -y
      The status should be success
      The output should eq "start one
end one
step two"
    End
  End

  Describe 'logging'
    setup() { LOGDIR=$(make_tmpdir)/log; }
    Before setup

    It 'writes output and trace logs to RB_LOG_DIR'
      export_logdir() { RB_LOG_DIR=$LOGDIR runbook "$@"; }
      When run export_logdir basic.md -q -s 1
      The status should be success
      The output should include 'step zeta'
      The path "$LOGDIR/basic.md.log" should be symlink
      The path "$LOGDIR/basic.md.trace" should be symlink
    End

    It 'writes no logs when RB_LOG_DIR is empty'
      When run runbook basic.md -s 1
      The output should not include 'Detailed runbook logs'
      The path "$SHELLSPEC_TMPBASE/log" should not be exist
    End

    It 'writes no logs with -qq even if RB_LOG_DIR is set'
      export_logdir() { RB_LOG_DIR=$LOGDIR runbook "$@"; }
      When run export_logdir basic.md -qq -s 1
      The output should eq 'step zeta'
      The path "$LOGDIR" should not be exist
    End
  End
End
