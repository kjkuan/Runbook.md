# shellcheck shell=bash

# Lines of the run summary, without the 'Runbook.md: ' prefix.
summary() { sed -n '/^Runbook.md: Summary:$/,/^Runbook.md: Done\.$/{s/^Runbook.md: //p}'; }

# The summary without durations.
summary_no_time() { summary | sed -E 's/ +[0-9]+\.[0-9]+s$//'; }

# "NAME STATUS" of each summary row.
statuses() {
    summary | awk 'NF >= 3 && $1 != "Summary:" { s = $3; if ($4 == "run") s = s " run"; print $2, s }'
}

# Output from the tasks themselves, i.e., lines not from Runbook.md.
task_output() { grep -v '^Runbook.md: ' || true; }

Describe 'Run summary'
  It 'shows the status of each selected step and task'
    When run runbook basic.md -s 2 -t Task/args
    The status should be success
    The output should include 'Skipped Step/zeta'
    The result of function "summary_no_time" should eq "Summary:
  2  Step/alpha  ok
  -  Task/args   ok
Done."
  End

  It 'marks the failed step, and the ones not run'
    When run runbook fail.md
    The status should be failure
    The stderr should be present
    The result of function "summary_no_time" should eq "Summary:
  1  Step/ok     ok
  2  Step/boom   FAILED
  3  Step/never  not run
Done."
  End

  It 'has durations for the steps that ran'
    When run runbook fail.md
    The status should be failure
    The stderr should be present
    The output should match pattern '*Step/ok *ok *[0-9].[0-9][0-9][0-9]s*'
    The output should match pattern '*Step/boom *FAILED *[0-9].[0-9][0-9][0-9]s*'
  End

  It 'marks a step already run by another step'
    Data 'y'
    When run runbook summary.md
    The status should be success
    The result of function "statuses" should include 'Step/two already run'
  End

  It 'marks a step skipped with Runbook/confirm-continue-task, even as the last one'
    Data 's'
    When run runbook summary.md
    The status should be success
    The result of function "task_output" should eq "one
two
three start"
    The result of function "statuses" should eq "Step/one ok
Step/two already run
Step/three skipped"
  End

  It 'marks a step stopped when quitting in Runbook/confirm-continue-task'
    Data 'q'
    When run runbook summary.md -s 3 -t Task/extra
    The status should be success
    The result of function "statuses" should eq "Step/three stopped
Task/extra not run"
  End

  It 'is not shown with -q'
    When run runbook basic.md -q
    The output should eq "step zeta
step alpha"
  End

  It 'is not shown when nothing is selected to run'
    When run runbook basic.md -s 0
    The output should not include 'Summary:'
  End

  It 'is not shown when rb-validate-env fails'
    When run runbook env.md
    The status should be failure
    The stderr should be present
    The output should not include 'Summary:'
  End
End

Describe '-i / --interactive'
  It 'runs a step on "y" and skips it on "s"'
    Data
      #|y
      #|s
    End
    When run runbook basic.md -i
    The status should be success
    The result of function "task_output" should eq 'step zeta'
    The output should include '*** Skipped Step/alpha ***'
    The result of function "statuses" should eq "Step/zeta ok
Step/alpha skipped"
  End

  It 'asks again on an invalid answer'
    Data
      #|maybe
      #|y
      #|y
    End
    When run runbook basic.md --interactive
    The status should be success
    The result of function "task_output" should eq "step zeta
step alpha"
  End

  It 'quits on "q" without running anything'
    Data 'q'
    When run runbook basic.md -i -t Task/hello
    The status should be success
    The result of function "task_output" should eq ''
    The result of function "statuses" should eq "Task/hello not run"
  End

  It 'also asks for tasks selected with -t, but not for their dependencies'
    Data 'y'
    When run runbook basic.md -i -t Task/dedupe
    The status should be success
    The result of function "task_output" should eq "hello a
hello b"
  End

  It 'does not ask with -y'
    When run runbook basic.md -i -y -q
    The status should be success
    The output should eq "step zeta
step alpha"
  End

  It 'fails when there is no answer'
    When run runbook basic.md -i
    The status should be failure
    The stderr should include 'No answer to the confirmation prompt (end of input).'
    The result of function "task_output" should eq ''
  End
End
