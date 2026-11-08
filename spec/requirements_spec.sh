# shellcheck shell=bash

Describe 'Requirement checks'
  It 'fails early when awk is not GNU awk'
    # A fake, non-GNU 'awk' ahead of the real one in PATH.
    fake_awk() {
        local dir; dir=$(make_tmpdir)
        printf '#!/bin/sh\necho "mawk 1.3.4"\n' > "$dir/awk"
        chmod +x "$dir/awk"
        PATH="$dir:$PATH" runbook basic.md "$@"
    }
    When run fake_awk -ls
    The status should be failure
    The output should eq ''
    The stderr should eq "Runbook.md: GNU awk (gawk) is required as 'awk'."
  End

  It 'passes with GNU awk'
    When run runbook basic.md -ls
    The status should be success
    The output should include 'Step/zeta'
  End
End
