# shellcheck shell=bash

Describe 'Task descriptions (-h)'
  It 'shows the general help with -h alone'
    When run runbook basic.md -h
    The status should be success
    The output should include 'Usage:'
    The output should include '-h TASK'
  End

  Describe '-h TASK'
    It 'shows the comment lines above the function definition'
      When run runbook basic.md -h Task/args
      The status should be success
      The line 1 of output should eq 'TASK'
      The line 2 of output should match pattern "        Task/args  (*/spec/fixtures/basic.md:$(line_of basic.md 'Task/args ()'))"
      The output should include 'DESCRIPTION'
      The output should include '        Print the runbook arguments.'
      The output should include '        They are the arguments after -- on the command line.'
      The output should not include '#'
    End

    It 'accepts a task name without the Task/ prefix'
      When run runbook basic.md -h args
      The status should be success
      The output should include '        Task/args  ('
      The output should include 'Print the runbook arguments.'
    End

    It 'accepts a step number'
      When run runbook basic.md -h 2
      The status should be success
      The output should include '        Step/alpha  ('
    End

    It 'shows no description for a function declared in the fence line'
      When run runbook basic.md -h hello
      The status should be success
      The output should include '(No description)'
    End

    It 'fails for an unknown task'
      When run runbook basic.md -h nope
      The status should be failure
      The stderr should include 'Unknown task: nope'
    End

    It 'does not treat a non-task function as a task'
      When run runbook basic.md -h helper
      The status should be failure
      The stderr should include 'Unknown task: helper'
    End

    It 'does not run any task'
      When run runbook basic.md -h Task/hello
      The output should not include 'hello world'
    End
  End

  Describe '-h with -ls / -lt'
    It 'shows the first non-blank description line as a summary'
      When run runbook basic.md -h -lt
      The status should be success
      The output should match pattern '*Task/args*Print the runbook arguments.*'
      The output should not include 'They are'
      The lines of output should eq 3
    End

    It 'shows summaries in the combined listing'
      When run runbook basic.md -ls -lt -h
      The status should be success
      The line 1 of output should match pattern '*1*Step/zeta*'
      The output should match pattern '*-*Task/args*Print the runbook arguments.*'
      The lines of output should eq 5
    End

    It 'does not show summaries without -h'
      When run runbook basic.md -lt
      The output should not include 'Print the runbook arguments.'
    End
  End
End
