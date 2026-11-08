# shellcheck shell=bash

Describe 'Markdown -> Bash conversion (RB_DUMP=1)'
  It 'preserves the line count so error line numbers map back to the .md file'
    When run dump_runbook convert.md
    The status should be success
    The lines of output should eq "$(wc -l < "$FIXTURES/convert.md")"
  End

  It 'turns prose into comments'
    When run dump_runbook convert.md
    The output should include '# # Conversion fixture'
    The output should include '# Some prose.'
  End

  It 'emits plain ```bash blocks as top-level code'
    When run dump_runbook convert.md
    The line "$(line_of convert.md 'TOP_LEVEL=1')" of output should eq 'TOP_LEVEL=1'
  End

  It 'wraps an inline declaration ending in { in a { } body'
    When run dump_runbook convert.md
    The line "$(line_of convert.md 'brace-func')" of output should start with 'function brace-func () {'
    The line "$(( $(line_of convert.md 'echo brace') + 1 ))" of output should eq '}'
  End

  It 'wraps an inline declaration ending in ( in a ( ) subshell body'
    When run dump_runbook convert.md
    The line "$(line_of convert.md 'subshell-func')" of output should start with 'function subshell-func () ('
    The line "$(( $(line_of convert.md 'echo subshell') + 1 ))" of output should eq ')'
  End

  It 'defaults to a { } body when no bracket is given'
    When run dump_runbook convert.md
    The line "$(line_of convert.md 'no-bracket-func')" of output should eq 'function no-bracket-func {'
  End

  It 'accepts an explicit "function" keyword'
    When run dump_runbook convert.md
    The line "$(line_of convert.md 'kw-func')" of output should eq 'function kw-func {'
  End

  It 'auto-numbers bare "Step" functions and strips fence comments'
    When run dump_runbook convert.md
    The line "$(line_of convert.md 'echo one')" of output should eq '    echo one'
    The line "$(( $(line_of convert.md 'echo one') - 1 ))" of output should start with 'function Step/1 '
    The line "$(( $(line_of convert.md 'echo two') - 1 ))" of output should start with 'function Step/2 '
    The output should not include 'becomes'
  End

  It 'executes ``` fenced blocks regardless of their language tag'
    When run dump_runbook convert.md
    The output should include '# ```sh'
    The line "$(line_of convert.md 'sh fence')" of output should eq 'echo "sh fence"'
  End

  It 'does not execute ~~~ or ```` fenced blocks'
    When run dump_runbook convert.md
    The output should include '# echo "tilde fence"'
    The output should include '# echo "four backticks"'
  End
End
