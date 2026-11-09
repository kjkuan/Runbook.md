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
      When run runbook fail.md -q
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

    # Names of the trace log files in the log directory.
    trace_files() { ls "$LOGDIR" | grep '\.trace$' || true; }

    It 'writes only the output log to RB_LOG_DIR by default'
      export_logdir() { RB_LOG_DIR=$LOGDIR runbook "$@"; }
      When run export_logdir basic.md -q -s 1
      The status should be success
      The output should include 'step zeta'
      The path "$LOGDIR/basic.md.log" should be symlink
      The path "$LOGDIR/basic.md.trace" should not be exist
      The result of function "trace_files" should eq ''
    End

    It 'also writes the trace log when RB_TRACE is non-empty'
      export_logdir() { RB_LOG_DIR=$LOGDIR RB_TRACE=x runbook "$@"; }
      When run export_logdir basic.md -q -s 1
      The status should be success
      The output should include 'step zeta'
      The path "$LOGDIR/basic.md.log" should be symlink
      The path "$LOGDIR/basic.md.trace" should be symlink
    End

    It 'traces the executed commands in the trace log'
      # Wait for the trace log writer to finish, after the runbook exits.
      run_and_read_trace() {
          RB_LOG_DIR=$LOGDIR RB_TRACE=x runbook "$@" >/dev/null
          local i; for ((i = 0; i < 50; i++)); do
              grep -q 'echo .step zeta' "$LOGDIR/basic.md.trace" 2>/dev/null && break
              sleep 0.1
          done
          cat "$LOGDIR/basic.md.trace"
      }
      When run run_and_read_trace basic.md -s 1
      The output should include "echo 'step zeta'"
    End

    It 'writes no trace log when RB_TRACE is set but empty'
      export_logdir() { RB_LOG_DIR=$LOGDIR RB_TRACE= runbook "$@"; }
      When run export_logdir basic.md -q -s 1
      The status should be success
      The output should include 'step zeta'
      The path "$LOGDIR/basic.md.trace" should not be exist
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
