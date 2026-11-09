# shellcheck shell=bash

Describe '-n / --dry-run'
  It 'shows all the steps by default, without running them'
    When run runbook basic.md -n
    The status should be success
    The output should eq "  1  Step/zeta
  2  Step/alpha"
  End

  It 'shows only the steps selected with -s'
    When run runbook basic.md --dry-run -s 2-
    The status should be success
    The output should eq "  2  Step/alpha"
  End

  It 'shows tasks in the order given with -t, after the selected steps'
    When run runbook basic.md -n -t Task/hello,Task/args -s 1
    The status should be success
    The output should eq "  1  Step/zeta
  -  Task/hello
  -  Task/args"
  End

  It 'works with the task shortcut'
    When run runbook basic.md -n hello
    The status should be success
    The output should eq "  -  Task/hello"
  End

  It 'shows nothing when nothing is selected'
    When run runbook basic.md -n -s 0
    The status should be success
    The output should eq ''
  End

  It 'is not suppressed by -q'
    When run runbook basic.md -n -q -s 1
    The output should eq "  1  Step/zeta"
  End

  It 'still reports invalid options'
    When run runbook basic.md -n -t Task/nope
    The status should be failure
    The stderr should include 'Function Task/nope is not defined!'
  End

  It 'does not call rb-validate-env'
    unset_env() { unset TARGET_HOST; runbook "$@"; }
    When run unset_env env.md -n
    The status should be success
    The output should eq "  1  Step/use-host"
  End

  It 'does not prompt with -i, nor write logs'
    with_logdir() { RB_LOG_DIR=$LOGDIR runbook "$@"; }
    LOGDIR=$(make_tmpdir)/log
    When run with_logdir basic.md -n -i
    The status should be success
    The output should eq "  1  Step/zeta
  2  Step/alpha"
    The path "$LOGDIR" should not be exist
  End
End
