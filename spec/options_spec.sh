# shellcheck shell=bash

Describe 'Runbook CLI options'
  It 'shows help with -h'
    When run runbook basic.md -h
    The status should be success
    The output should include 'Usage:'
    The output should include '--steps=LIST'
  End

  It 'rejects unknown options'
    When run runbook basic.md --bogus
    The status should be failure
    The stderr should include 'Unknown option: --bogus'
  End

  Describe '-ls / -lt'
    It 'lists steps in definition order, not name order'
      When run runbook basic.md -ls
      The status should be success
      The lines of output should eq 2
      The line 1 of output should match pattern '*1*Step/zeta'
      The line 2 of output should match pattern '*2*Step/alpha'
    End

    It 'lists tasks only'
      When run runbook basic.md -lt
      The output should include 'Task/hello'
      The output should include 'Task/args'
      The output should include 'Task/dedupe'
      The output should not include 'Step/'
      The output should not include 'helper'
    End

    It 'lists both with -ls -lt'
      When run runbook basic.md -ls -lt
      The output should include 'Step/zeta'
      The output should match pattern '*-*Task/hello*'
    End
  End

  Describe 'default run'
    It 'runs all steps in definition order and no tasks'
      When run runbook basic.md
      The status should be success
      The output should include 'step zeta'
      The output should include 'step alpha'
      The output should not include 'hello'
      The output should match pattern '*step zeta*step alpha*'
    End
  End

  Describe '-s LIST'
    Parameters
      '1'           'step zeta'  'step alpha'
      '2'           'step alpha' 'step zeta'
      '2-'          'step alpha' 'step zeta'
      '-1'          'step zeta'  'step alpha'
      'Step/alpha'  'step alpha' 'step zeta'
      '--steps=1'   'step zeta'  'step alpha'
    End

    It "runs only the selected step for '$1'"
      if [[ $1 == --* ]]; then
        When run runbook basic.md "$1"
      else
        When run runbook basic.md -s "$1"
      fi
      The status should be success
      The output should include "$2"
      The output should not include "$3"
    End

    It 'skips all steps with 0'
      When run runbook basic.md -s 0
      The status should be success
      The output should not include 'step zeta'
      The output should not include 'step alpha'
      The output should include 'Skipped Step/zeta'
    End

    It 'rejects an unknown step name'
      When run runbook basic.md -s Step/nope
      The status should be failure
      The stderr should include 'Invalid task range spec: Step/nope'
    End

    It 'rejects a decreasing range'
      When run runbook basic.md -s 2-1
      The status should be failure
      The stderr should include 'Invalid decreasing task range: 2-1'
    End

    It 'fails when the LIST argument is missing'
      When run runbook basic.md -s
      The status should be failure
      The stderr should include 'Usage:'
    End
  End

  Describe '-t LIST'
    It 'runs tasks in the given order and skips steps'
      When run runbook basic.md -t Task/args,Task/hello
      The status should be success
      The output should match pattern '*args:*hello world*'
      The output should not include 'step zeta'
    End

    It 'can be given multiple times'
      When run runbook basic.md -t Task/hello -t Task/args
      The output should match pattern '*hello world*args:*'
    End

    It 'runs selected steps before tasks when combined with -s'
      When run runbook basic.md -t Task/hello -s 2
      The output should match pattern '*step alpha*hello world*'
      The output should not include 'step zeta'
    End

    It 'rejects an undefined function'
      When run runbook basic.md -t Task/nope
      The status should be failure
      The stderr should include 'Function Task/nope is not defined!'
    End

    It 'rejects a function that is not a task'
      When run runbook basic.md -t helper
      The status should be failure
      The stderr should include "helper doesn't match"
    End
  End

  Describe 'task shortcut'
    It 'runs Task/NAME for a bare NAME argument without stray output'
      When run runbook basic.md hello
      The status should be success
      The line 1 of output should start with 'Runbook.md: === Executing Task/hello'
      The output should include 'hello world'
      The output should not include 'step zeta'
    End
  End

  Describe 'runbook arguments'
    It 'passes arguments after -- to the runbook'
      When run runbook basic.md -t Task/args -- -x foo
      The output should include 'args: -x foo'
    End
  End

  Describe '-q / -qq'
    It 'suppresses Runbook.md info messages with -q'
      When run runbook basic.md -q -s 1
      The output should eq 'step zeta'
    End

    It 'suppresses Runbook.md info messages with -qq'
      When run runbook basic.md -qq -s 1
      The output should eq 'step zeta'
    End
  End
End
