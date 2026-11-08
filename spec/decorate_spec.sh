# shellcheck shell=bash

Describe 'Runbook.sh (run directly)'
  setup() { DIR=$(make_tmpdir); }
  Before setup

  It 'shows usage and fails with no arguments'
    When run bash "$SHELLSPEC_PROJECT_ROOT/Runbook.sh"
    The status should be failure
    The output should include '-x FILE'
  End

  It 'fails when -x is missing its argument'
    When run bash "$SHELLSPEC_PROJECT_ROOT/Runbook.sh" -x
    The status should be failure
    The stderr should include 'Usage:'
    The stderr should include 'Missing required argument'
  End

  Describe '-x FILE'
    It 'creates a new executable runbook with an example task'
      When run bash "$SHELLSPEC_PROJECT_ROOT/Runbook.sh" -x "$DIR/new.md"
      The status should be success
      The path "$DIR/new.md" should be executable
      The line 3 of contents of file "$DIR/new.md" should eq 'source Runbook.sh RUN "$@"'
      The contents of file "$DIR/new.md" should include 'rb-main "$@"'
    End

    It 'produces a runbook that runs'
      decorate_and_list() {
          bash "$SHELLSPEC_PROJECT_ROOT/Runbook.sh" -x "$DIR/new.md" &&
          (cd "$DIR" && bash new.md -lt)
      }
      When run decorate_and_list
      The status should be success
      The output should eq 'Task/do-something'
    End

    It 'decorates an existing Markdown file, keeping its content'
      decorate_existing() {
          printf '# Mine\n\n```bash Task/mine\n    echo mine\n```\n' > "$DIR/mine.md"
          bash "$SHELLSPEC_PROJECT_ROOT/Runbook.sh" -x "$DIR/mine.md" &&
          (cd "$DIR" && bash mine.md -qq mine)
      }
      When run decorate_existing
      The status should be success
      The output should eq 'mine'
    End

    It 'does not decorate a file twice'
      decorate_twice() {
          bash "$SHELLSPEC_PROJECT_ROOT/Runbook.sh" -x "$DIR/new.md" &&
          bash "$SHELLSPEC_PROJECT_ROOT/Runbook.sh" -x "$DIR/new.md" &&
          grep -c 'source Runbook.sh RUN' "$DIR/new.md"
      }
      When run decorate_twice
      The status should be success
      The line 1 of output should include 'already been decorated'
      The line 2 of output should eq 1
    End
  End
End
