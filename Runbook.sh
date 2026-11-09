#!/usr/bin/env bash
#
# BSD 2-Clause License
#
# Copyright (c) 2021, Jack Kuan
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

#TODOs:
#  - Show the task function source code with -h TASK?
#  - Add an option to confirm all step executions.
#  - Add an option to resume from the last failed step.
#

# Check the requirements first. NOTE: Keep this check parsable by old versions
# of Bash, so that it can run before Bash gets to the code it can't parse.
if (( BASH_VERSINFO[0] < 5 )); then
    echo "Runbook.md: Bash 5.0 or newer is required, but this is Bash $BASH_VERSION." >&2
    exit 1
fi
if [[ $(awk --version 2>/dev/null) != "GNU Awk"* ]]; then
    echo "Runbook.md: GNU awk (gawk) is required as 'awk'." >&2
    exit 1
fi

# If we are being sourced and told to RUN the sourcing doc
if [[ $0 != "$BASH_SOURCE" && $1 == RUN ]]; then
    shift # the 'RUN'

    # Save the STDIN for later use by the runbook
    exec {RB_STDIN}<&0; export RB_STDIN

    # Invert the Markdown text and the Bash examples in the document, turning it
    # into a Bash script with the examples as code and everything else as comments.
    awk '
        /^```(\s|\w|$)/ {
            if (!IN_CODE) {  # opening fence
                line = $0
                gsub(/^```|#.*$/, "")
                if (split($0, tokens) > 1 && tokens[1] == "bash") {
                    FUNC_DECL = 1
                    gsub(/^\s*bash\s*/, "")
                    match($0, /([{(])\s*$/, tokens)
                    BRACKET = tokens[1]
                    gsub(/^\s*function\s+/, "")
                    if ($0 ~ /^Step(\s|$)/) sub(/^Step/, "Step/" ++STEP)
                    print "function", $0, BRACKET ? "" : "{"
                } else
                    print "#", line
                IN_CODE = 1
                next
            } else if (match($0, /^```$/)) { # closing fence
                if (FUNC_DECL) {
                    if (BRACKET == "{") print "}"
                    if (BRACKET == "(") print ")"
                    if (BRACKET == "" ) print "}"
                } else
                    print "#", $0
                FUNC_DECL = 0
                IN_CODE   = 0
                next
            }
        }
        { if (IN_CODE) print; else print "#", $0 }
    ' "$0" \
           |
    if [[ ${RB_DUMP:-} ]]; then # just show the generated script
        cat
    else
        if [[ ${RB_FROM_STDIN:-} ]]; then
            exec bash -s "$0" "$@"
        else
            exec bash -c "$(cat)" "$0" "$@" <&$RB_STDIN
        fi
    fi
    exit
fi

# For when Runbook.sh is executed by itself
if [[ $0 == "$BASH_SOURCE" ]]; then
    set -eo pipefail
    show-usage () {
            cat <<EOF
Usage: ${0##*/} [options]

Options:

  -h, --help  Show this help.

  -x FILE     Make FILE a Markdown file executable by Runbook.md. FILE will be
              created if it doesn't already exist.

EOF
    }
    (( $# )) || { show-usage; exit 1; }

    decorate-file () {
        local file=${1:?}
        if [[ -e $file ]]; then
            [[ -r $file && -w $file ]] || {
                echo "$file doesn't appear to be both readable and writable!" >&2
                exit 1
            }
        else
            cat > "$file" <<'EOF'
# Put your runbook content here

Example task:
```bash
Task/do-something () {
    echo 'Doing work ...'
    sleep 1
    echo Done.
}
```
EOF
        fi
        # Check the first non-blank line for the header. The '[&>/dev/null; touch'
        # form is the header written by older versions of Runbook.md.
        local line
        while read -r line; do
            [[ $line ]] && break
        done < "$file"
        if [[ $line == '[>/dev/null 2>&1; touch '* || $line == '[&>/dev/null; touch '* ]]; then
            echo "It looks like $file has already been decorated by Runbook.md."
            chmod +x "$file"
            exit
        fi
        local content; content=$(
            cat <<'HEADER'
[>/dev/null 2>&1; touch "!---$$"; : ]: # (Please keep this and the comment below)
<!---$$ >/dev/null 2>&1; rm -f "!---$$"
source Runbook.sh RUN "$@"
```
source Runbook.sh
```
----------------------------------------------------------------------------->
HEADER
                cat "$file"
                cat <<'FOOTER'
<!---Please keep this comment-------------------------------------------------
```
rb-main "$@"
```
----------------------------------------------------------------------------->
FOOTER
        )
        echo "$content" > "$file"
        chmod +x "$file"
    }

    while (( $# )); do
        opt=$1; shift
        case $opt in
            -h|--help) show-usage; exit
                ;;
            -x) file=$1; shift || {
                  show-usage
                  echo "-x: Missing required argument!"
                  exit 1
                } >&2
                ;;
            *) { echo "Unknown option: $opt"; show-usage; } >&2; exit 1
                ;;
        esac
    done
    if [[ $file ]]; then
        decorate-file "$file"
    fi
    exit
fi

set -eEo pipefail
shopt -s inherit_errexit compat43

# Save the path to the original runbook file as $0
if [[ ${RB_FROM_STDIN:-} ]]; then
    BASH_ARGV0=$(cd "$(dirname "$1")"; echo "$PWD/${1##*/}"); shift
else
    BASH_ARGV0=$(cd "$(dirname "$0")"; echo "$PWD/${0##*/}")
fi

RB_START_TIME=$EPOCHREALTIME
RB_LOG_DIR=${RB_LOG_DIR-"$PWD/log"}
RB_LOG_FROM_START=${RB_LOG_FROM_START:-}
RB_STEP_REGEX=${RB_STEP_REGEX:-^Step/}
RB_TASK_REGEX=${RB_TASK_REGEX:-^Task/}

RB_EXIT_CMDS=()
RB_CLI_ARGS=()
RB_STEPS=()  # all the defined steps; steps are ordered tasks.
RB_TASKS=()  # tasks to be run
#RB_LOG_LEVEL=

declare -A RB_CLI_OPTS=()
declare -A RB_STEPS_TO_RUN=()  # steps to be run

# For saving task attributes; currently used to keep track of the dynamic
# dependency of task executions started by rb-run().
#
declare -A RB_TASK=()

if [[ ! ${NO_COLOR:-} ]]; then
    RB_NC='\e[0m'   # No Color
    RB_FG='\e[39m'  # Default foreground color
    RB_BLACK='\e[0;30m'
    RB_WHITE='\e[1;37m'
    RB_RED='\e[0;31m'    RB_LIGHTRED='\e[1;31m'
    RB_GREEN='\e[0;32m'  RB_LIGHTGREEN='\e[1;32m'
    RB_BLUE='\e[0;34m'   RB_LIGHTBLUE='\e[1;34m'
    RB_YELLOW='\e[0;33m' RB_LIGHTYELLOW='\e[1;33m'
    RB_PURPLE='\e[0;35m' RB_LIGHTPURPLE='\e[1;35m'
    RB_CYAN='\e[0;36m'   RB_LIGHTCYAN='\e[1;36m'
    RB_GRAY='\e[1;30m'   RB_LIGHTGRAY='\e[0;37m'
else
    RB_NC=
    RB_FG=
    RB_BLACK=
    RB_WHITE=
    RB_RED=    RB_LIGHTRED=
    RB_GREEN=  RB_LIGHTGREEN=
    RB_BLUE=   RB_LIGHTBLUE=
    RB_PURPLE= RB_LIGHTPURPLE=
    RB_YELLOW= RB_LIGHTYELLOW=
    RB_CYAN=   RB_LIGHTCYAN=
    RB_GRAY=   RB_LIGHTGRAY=
fi

rb-info  () { echo -e "${RB_CYAN}Runbook.md: $*${RB_NC}"; }
rb-error () { echo -e "${RB_RED}Runbook.md: $*${RB_NC}" >&2; }
rb-die   () { echo -e "${RB_LIGHTRED}Runbook.md: $*${RB_NC}" >&2; exit 1; }

# This extra function call makes it possible to show the line that returns
# the non-zero status from a function before exiting due to set -e.
#
rb-fail () { local n=${1:-$?}; (( $n > 0 )) || n=1; command return $n; }

rb-dump-stack-trace () {
    local rc=$?; trap ERR
    local lineno=$1 func=$2 file=$3
    _rb-dump-stack-trace () {
        if [[ ! $file || $file == @(main|environment) ]]; then file=$0; fi
        echo "File $file, line $lineno${func:+", in $func ()"}:"
        echo -e "$RB_FG$(mapfile -tn1 -s $((lineno - 1)) l < "$file"; echo "$l")$RB_RED"
    }
    rb-error "--- Stack trace from shell process $BASHPID depth=$BASH_SUBSHELL -------------"
    rb-error "Return status: $rc"
    echo -ne "$RB_RED"
    _rb-dump-stack-trace
    while caller $((i++)); do :; done \
      |
    while read -r lineno func file; do
        _rb-dump-stack-trace
    done
    echo -ne "$RB_NC"
    rb-error "------------------------------------------------------------------------------"
} >&2
trap 'rb-dump-stack-trace $LINENO "$FUNCNAME" "$BASH_SOURCE"' ERR

rb-run-exit-commands () {
    RB_EXIT_STATUS=$?
    set +e  # so that we do as much clean up as possible.

    # Restore stdout and stderr so that in the case of an interactive Ctrl-C,
    # which would killed the logging child process that we redirected stdout
    # and stderr to, we'd still be able to see some messages.
    [[ ${RB_STDOUT:-} && ${RB_STDERR:-} ]] && exec >&$RB_STDOUT 2>&$RB_STDERR

    local i=$(( ${#RB_EXIT_CMDS[*]} - 1))
    if (( i >= 0 )); then
        for i in $(seq $i -1 0); do eval "${RB_EXIT_CMDS[$i]}"; done
    fi
}
trap rb-run-exit-commands EXIT

_rb-tstamp-lines () {
    local tfmt=${1:?} line
    while IFS='' read -r line; do
        printf "%($tfmt)T %s\n" -1 "$line"
    done
}
rb-start-logging () {
    # if RB_LOG_DIR is set and empty then disable logging entirely.
    if [[ ! $RB_LOG_DIR ]]; then
        RB_STDOUT=1 RB_STDERR=2
        return 0
    fi
    exec {RB_STDOUT}>&1 {RB_STDERR}>&2
    mkdir -p "$RB_LOG_DIR"; RB_LOG_DIR=$(cd "$RB_LOG_DIR" && pwd)
    local tfmt=%Y-%m-%dT%T
    local logfd tstamp=$(date +$tfmt)
    rb-info "Detailed runbook logs can be found in $RB_LOG_DIR/"

    local output_log=$RB_LOG_DIR/${0##*/}_$tstamp.log
    touch "$output_log"
    ln -nfs "$output_log" "${output_log%/*}/${0##*/}.log"

    # The trace log has every command executed, with all expansions, which might
    # include secrets; so it's only written if RB_TRACE is non-empty.
    if [[ ${RB_TRACE:-} ]]; then
        local trace_log=$RB_LOG_DIR/${0##*/}_$tstamp.trace
        touch "$trace_log"
        ln -nfs "$trace_log" "${trace_log%/*}/${0##*/}.trace"

        exec {logfd}> >(set +x; _rb-tstamp-lines $tfmt > "$trace_log")
        BASH_XTRACEFD=$logfd
        if [[ $PS4 == "+ " ]]; then
            #export PS4='+ $BASH_SOURCE:$LINENO in (${FUNCNAME[*]:0:${#FUNCNAME[*]}-1}): '
            export PS4='+ $FUNCNAME():$LINENO: '
        fi
        set -x
    fi
    exec 1> >(exec tee >(set +x; _rb-tstamp-lines $tfmt > "$output_log")) 2>&1
}

rb-show-help () {
    cat <<EOF
Usage: $0 [options] [args]

Options:
    -h, --help        Show this help.

    -h TASK           Show the description of TASK (a task name or a step number).

    -ls               List all steps in the order they are defined in the runbook.
                      With -h, also show a summary of each step.

    -lt               List all the non-step tasks defined in the runbook, with a
                      summary of each.

    -s, --steps=LIST  Run only steps specified by LIST, which is a list of comma
                      separated task indexes (as shown with option '-ls') and / or
                      index ranges of the following forms: (similar to 'cut -f LIST')

                        0     A special case that skips all steps.
                        N     The N-th step.
                        N-    From the N-th step to the last step.
                        N-M   From the N-th step to the M-th step. (M >= N)
                        -M    From the first step to the M-th step.
                        NAME  Name of the step function to be executed.

                      LIST defaults to '1-', which runs all steps.

                      Steps selected by LIST will always be executed first at the end
                      of the runbook, in the order they are defined, before any non-step
                      tasks. This option can be specified multiple times.

    -t, --tasks=LIST  Run the tasks in the order specified in LIST, which is a list of
                      comma separated task function names, including step function names.
                      Unless a step is also specified with '-s', no steps will be run when
                      this option is used. This option can be specified multiple times.

    -n, --dry-run     Show the steps and tasks that would be run, in order, without
                      running them. (Steps and tasks they run with rb-run aren't shown.)

    -i, --interactive Confirm before running each selected step or task.

    -y, --yes         Say yes to all task confirmation prompts.

    -q, --quiet       Suppress Runbook.md's STDOUT logs about task executions.
                      Error logs will still go to STDERR.

    -qq, --no-logs    Disable logging completely; same as -q plus setting RB_LOG_DIR to
                      an empty string.

    --                Pass the rest of CLI args to the runbook.

Environment variable options:

    RB_LOG_DIR         - Directory to save the log files to. (Defaults to ./log)
                         To disable logging to files, set it to an empty string.

    RB_LOG_FROM_START  - If set to non-empty, start logging at the start of the runbook
                         script's execution. (Default is to start logging only when task
                         execution starts)

    RB_TRACE           - Set to non-empty to also write a trace log, which has every
                         command executed with all expansions. (Beware of secrets!)

    RB_STEP_REGEX      - Regex used to match a step function. Defaults to ^Step/

    RB_TASK_REGEX      - Regex used to match a task function. Defaults to ^Task/

    NO_COLOR           - Set to non-empty to disable colored outputs.

EOF
}
# Process runbook CLI options; remaining args will be put in the RB_CLI_ARGS array.
#
rb-parse-options () {   # "$@"
    while (( $# )); do
        local opt=$1; shift
        case $opt in
          -h|--help) RB_CLI_OPTS[help]=x ;;

          -ls) RB_CLI_OPTS[list-steps]=x ;;
          -lt) RB_CLI_OPTS[list-tasks]=x ;;

          -s|--steps|--steps=*)
              if [[ $opt == *=* ]]; then
                  RB_CLI_OPTS[step-list]+=${opt#*=},
              else
                  RB_CLI_OPTS[step-list]+=$1,
                  shift || { rb-show-help >&2; rb-fail; }
              fi
              ;;

          -t|--tasks|--tasks=*)
              if [[ $opt == *=* ]]; then
                  RB_CLI_OPTS[task-list]+=${opt#*=},
              else
                  RB_CLI_OPTS[task-list]+=$1,
                  shift || { rb-show-help >&2; rb-fail; }
              fi
              ;;

          -n|--dry-run) RB_CLI_OPTS[dry-run]=x ;;
          -i|--interactive) RB_CLI_OPTS[interactive]=x ;;
          -y|--yes) RB_CLI_OPTS[yes]=x ;;

          -q|--quiet) rb-info () { :; } ;;
          -qq|--no-logs) rb-info () { :; }; RB_LOG_DIR= ;;

          --) RB_CLI_ARGS=("$@"); break ;;
          -*) rb-show-help >&2; rb-error "Unknown option: $opt"; rb-fail ;;
           *) RB_CLI_ARGS=("$opt" "$@"); break ;;
        esac
    done

    # Show the general help right away, unless -h is used with -ls, -lt or a
    # task, in which case rb-main shows it once all tasks are defined.
    if [[ ${RB_CLI_OPTS[help]:-} &&
          ! ${RB_CLI_OPTS[list-steps]:-}${RB_CLI_OPTS[list-tasks]:-} &&
          ! ${RB_CLI_ARGS[*]:-} ]]
    then
        rb-show-help; exit
    fi
}

_rb-compute-steps-range () {
    local range_regex='^(0|[1-9][0-9]*|[1-9][0-9]*-|-[1-9][0-9]*|[1-9][0-9]*-[1-9][0-9]*)$'
    local range ranges; readarray -td, ranges < <(echo -n "${1:?}")
    local task_count=${2:?}
    local task_names; task_names=$(rb-list-steps)
    for range in "${ranges[@]}"; do
        [[ $range =~ $range_regex ]] || {
            # might be a task function name
            local r=$(set +o pipefail; grep -F -m1 -xn "$range" <<<"$task_names" | cut -d: -f1)
            if [[ ! $r ]]; then
                rb-error "Invalid task range spec: ${range}"
                rb-fail
            else
                range=$r
            fi
        }
        IFS=- read -r low high <<<"$range"
        if [[ $range != *-* ]]; then
            RB_STEPS_TO_RUN[$low]=x
        else
            [[ $high ]] || high=$task_count
            [[ $low  ]] || low=1
            (( low <= high )) || {
                rb-error "Invalid decreasing task range: $range"
                rb-fail
            }
            local i
            for ((i=$low; i<=$high; i++)); do
                RB_STEPS_TO_RUN[$i]=x
            done
        fi
    done
}

rb-list-steps () (
    local func_names; func_names=$(
        declare -F \
          | cut -d' ' -f3- \
          | grep -E "${RB_STEP_REGEX:?}" || true
    )
    [[ $func_names ]] || return 0

    # To get the line number where a function is defined.
    set -f; shopt -s extdebug

    declare -F $func_names \
      | sort -nk2,2 \
      | cut -d' ' -f1
)

rb-list-tasks () {
    declare -F | cut -d' ' -f3- | grep -E "${RB_TASK_REGEX:?}" || true
}

# Print "LINENO FILE" of where a function is defined.
# NOTE: Call it in a subshell (e.g., $(...) or <(...)), since it sets extdebug.
_rb-function-location () {
    shopt -s extdebug
    declare -F "${1:?}" | cut -d' ' -f2-
}

# Print the description of the function defined at line $1 of the runbook,
# which is the consecutive comment lines right above the function definition
# within its fenced code block. A function declared in the opening fence line
# (e.g., ```bash Task/foo) has no description.
_rb-function-description () {
    awk -v lineno="${1:?}" '
        NR == lineno {
            if ($0 !~ /^```/) for (j = 0; j < n; j++) print lines[j]
            exit
        }
        /^[[:space:]]*#/ { lines[n++] = $0; next }
                         { n = 0 }
    ' "$0" | sed -E 's/^[[:space:]]*#+[[:space:]]?//'
}

# Print the first non-blank line of a function's description.
_rb-function-summary () {
    _rb-function-description "$1" | awk 'NF { print; exit }'
}

# Read function names from STDIN; print each with its summary if -h is given,
# or if the first argument is non-empty.
_rb-add-summaries () {   # [ALWAYS]
    local name lineno file
    while read -r name; do
        if [[ ${1:-} || ${RB_CLI_OPTS[help]:-} ]]; then
            read -r lineno file < <(_rb-function-location "$name")
            local summary=
            if [[ $file == @(main|environment|"$0") ]]; then
                summary=$(_rb-function-summary "$lineno")
            fi
            printf '%s\t%s\n' "$name" "$summary"
        else
            echo "$name"
        fi
    done
}

# Show detailed help of a task, specified by its function name, its name
# without the 'Task/' prefix, or its step number.
rb-show-task-help () {
    local name=${1:?} task steps lineno file indent='        '
    mapfile -t steps < <(rb-list-steps)
    if [[ $name =~ ^[1-9][0-9]*$ ]] && (( name <= ${#steps[*]} )); then
        task=${steps[name - 1]}
    else
        for task in "$name" "Task/$name" ''; do
            if [[ $task =~ $RB_TASK_REGEX || $task =~ $RB_STEP_REGEX ]] &&
               declare -F "$task" >/dev/null
            then
                break
            fi
        done
        [[ $task ]] || rb-die "Unknown task: $name"
    fi
    read -r lineno file < <(_rb-function-location "$task")

    echo -e "${RB_CYAN}TASK${RB_NC}"
    echo "$indent$task  (${0#"$PWD/"}:$lineno)"
    echo
    echo -e "${RB_CYAN}DESCRIPTION${RB_NC}"
    local desc=
    if [[ $file == @(main|environment|"$0") ]]; then
        desc=$(_rb-function-description "$lineno")
    fi
    if [[ $desc ]]; then
        sed "s/^/$indent/" <<<"$desc" | fmt -s
    else
        echo "${indent}(No description)"
    fi
}

_rb-calculate-duration () {
    printf -v t1 "%.3f" "$t1"; t1=${t1/.}
    printf -v t2 "%.3f" "$t2"; t2=${t2/.}
    printf -v dt "%.4d" "$(( t2 - t1 ))"
    local f=${dt:${#dt}-3}
    dt=${dt%???}.${f:-000}
}

# Print "STEP_NUMBER<TAB>NAME<TAB>SELECTED" for the steps in their definition
# order, followed by the tasks in the order specified in the CLI. SELECTED is
# 'x', or empty for a step not selected with -s. A task's step number is '-'.
#
_rb-run-list () {
    local task i=0 selected
    if [[ ! ${RB_CLI_OPTS[task-list]:-} || ${RB_CLI_OPTS[step-list]:-} ]]; then
        for task in "${RB_STEPS[@]}"; do
            i=$(( i + 1 ))
            selected=
            if [[ ! ${RB_CLI_OPTS[step-list]:-} || ${RB_STEPS_TO_RUN[$i]:-} ]]; then
                selected=x
            fi
            printf '%s\t%s\t%s\n' "$i" "$task" "$selected"
        done
    fi
    for task in "${RB_TASKS[@]}"; do
        printf -- '-\t%s\tx\n' "$task"
    done
}

# Run the steps specified in their definition order first, then
# run the tasks in the order specified in the CLI.
#
rb-run-tasks () {
    local rows row _rb_step_i task selected
    mapfile -t rows < <(_rb-run-list)
    for row in "${rows[@]}"; do
        IFS=$'\t' read -r _rb_step_i task selected <<<"$row"
        if [[ ! $selected ]]; then
            rb-info "*** Skipped $task due to unspecified step number: $_rb_step_i ***"
            continue
        fi
        [[ $_rb_step_i != - ]] || _rb_step_i=
        rb-run "$task"
    done
}

rb-run () {
    local task=${1:?} key="$*"; shift

    # Whether it's a step or task selected to run, rather than a dependency.
    local selected=; [[ ${FUNCNAME[1]:-} != rb-run-tasks ]] || selected=x

    if [[ ${RB_TASK[$key@run_by]:-} ]]; then
        if [[ $selected && ! ${RB_TASK[$key@status]:-} ]]; then
            _rb-set-run-status "$key" 'already run'
        fi
        return 0
    fi

    local t1 t2 dt step_note
    [[ $task =~ $RB_STEP_REGEX ]] && [[ ${_rb_step_i:-} ]] && step_note="Step $_rb_step_i" || step_note=

    if [[ $selected ]]; then
        if [[ ${RB_CLI_OPTS[interactive]:-} ]] &&
           ! _rb-ask-yes-skip-quit "Run $task${step_note:+" ($step_note)"}"
        then
            rb-info "*** Skipped $task ***"
            _rb-set-run-status "$key" skipped
            return 0
        fi
        _rb-set-run-status "$key" running
    fi

    rb-info "${RB_YELLOW}=== Executing $task${*:+" $*"} ${step_note:+"($step_note) "}=========================="
    t1=$EPOCHREALTIME
    "$task" "$@"
    t2=$EPOCHREALTIME
    _rb-calculate-duration
    rb-info "${RB_GREEN}=== Successfully executed $task${*:+" $*"} (${step_note:+"$step_note; "}took $dt seconds) =============="
    [[ ! $selected ]] || _rb-set-run-status "$key" ok

    local i
    for ((i=1; i < ${#FUNCNAME[*]}; i++)); do
        if [[ ${FUNCNAME[i]} =~ $RB_TASK_REGEX ]] ||
           [[ ${FUNCNAME[i]} =~ $RB_STEP_REGEX ]]
        then
            RB_TASK[$key@run_by]=${FUNCNAME[i]}
            return
        fi
    done
    RB_TASK[$key@run_by]=${FUNCNAME[1]:-0}
}

# Record the status of a step or task selected to run, and its duration once
# it's no longer running.
_rb-set-run-status () {   # KEY STATUS
    local key=${1:?} t1 t2 dt
    if [[ ${2:?} == running ]]; then
        # The previous one is still running only if it skipped the rest of
        # itself with Runbook/confirm-continue-task.
        if [[ ${RB_RUN_CURRENT:-} && ${RB_TASK[$RB_RUN_CURRENT@status]} == running ]]; then
            _rb-set-run-status "$RB_RUN_CURRENT" skipped
        fi
        RB_RUN_CURRENT=$key
        RB_TASK[$key@start]=$EPOCHREALTIME
    elif [[ ${RB_TASK[$key@start]:-} ]]; then
        t1=${RB_TASK[$key@start]} t2=$EPOCHREALTIME
        _rb-calculate-duration
        RB_TASK[$key@time]=$dt
    fi
    RB_TASK[$key@status]=$2
}

# Ask a [Y]es/[S]kip/[Q]uit question, unless -y is given. Return 0 for yes,
# or 1 for skip; exit the runbook for quit.
_rb-ask-yes-skip-quit () {   # QUESTION
    [[ ! ${RB_CLI_OPTS[yes]:-} ]] || return 0
    local ans
    while true; do
        read -u "${RB_STDIN:?}" -rp "Runbook.md: $1 ([Y]es/[S]kip/[Q]uit)? " ans ||
            rb-die "No answer to the confirmation prompt (end of input)."
        case ${ans,,} in
          y|yes ) return 0 ;;
          s|skip) return 1 ;;
          q|quit) exit ;;
        esac
    done
}

# Show the status and duration of each step and task selected to run.
rb-show-run-summary () {
    local rows step task status line color
    rows=$(_rb-run-list | grep $'\tx$' || true)
    [[ $rows ]] || return 0

    rb-info "Summary:"
    while IFS=$'\t' read -r step task _; do
        status=${RB_TASK[$task@status]:-not run}
        if [[ $status == running ]]; then  # it's where the runbook exited
            if (( RB_EXIT_STATUS )); then
                status=FAILED
            elif [[ ${RB_RUN_DONE:-} ]]; then
                status=skipped
            else
                status=stopped
            fi
            _rb-set-run-status "$task" "$status"
        fi
        printf '%3s\t%s\t%s\t%s\n' "$step" "$task" "$status" \
               "${RB_TASK[$task@time]:+${RB_TASK[$task@time]}s}"
    done <<<"$rows" \
      |
    column -ts$'\t' \
      |
    while IFS= read -r line; do
        line=${line%"${line##*[! ]}"}  # strip the padding of an empty last column
        case $line in
          *' ok '*     ) color=$RB_GREEN ;;
          *' FAILED '* ) color=$RB_RED ;;
          *' not run'  ) color=$RB_GRAY ;;
          *            ) color=$RB_YELLOW ;;
        esac
        rb-info "$color$line"
    done
}

rb-show-total-runtime () {
    local t1=$RB_START_TIME t2=$EPOCHREALTIME dt
    _rb-calculate-duration
    rb-info "Done."
    rb-info "Total runtime: $dt seconds"
}

# Main entry point to be called at the end of a runbook to
# handle runbook options and start running tasks.
rb-main () {
    # Work around the fact that 'column' might not be available on some system.
    if ! type -P column >/dev/null; then
        column () { sed $'s/\t/  /g'; }
    fi
    (
        if [[ ${RB_CLI_OPTS[list-steps]:-} ]]; then
            rb-list-steps | _rb-add-summaries | nl -ba -s$'\t' -w3
        fi
        if [[ ${RB_CLI_OPTS[list-tasks]:-} ]]; then
            rb-list-tasks \
                |
            _rb-add-summaries always \
                |
            if [[ ${RB_CLI_OPTS[list-steps]:-} ]]; then
                sed $'s/^/  -\t/'
            else
                cat
            fi
        fi
    ) \
      |
    column -ts$'\t' \
      |
    sed 's/[[:space:]]*$//'  # strip the padding of an empty last column

    if [[ ${RB_CLI_OPTS[list-steps]:-} || ${RB_CLI_OPTS[list-tasks]:-} ]]; then
        exit
    fi

    if [[ ${RB_CLI_OPTS[help]:-} ]]; then
        rb-show-task-help "${1:?}"
        exit
    fi

    # shortcut to run Task/$1 if no -s nor -t are specified
    if ! [[ ${RB_CLI_OPTS[step-list]:-} || ${RB_CLI_OPTS[task-list]:-} ]]; then
        if [[ ${1:-} ]] && declare -F "Task/$1" >/dev/null; then
            RB_CLI_OPTS[task-list]=Task/$1
        fi
    fi

    local oset=$(shopt -op noglob || true); set -f
    RB_STEPS=($(rb-list-steps))
    RB_TASKS=(
      $(IFS=,
        for t in ${RB_CLI_OPTS[task-list]:-}; do
            declare -F "$t" || { rb-error "Function $t is not defined!"; exit 1; }
            [[ $t =~ $RB_TASK_REGEX ]] || {
                rb-error "$t doesn't match '$RB_TASK_REGEX'; therefore, it's not a task!"
                exit 1
            }
        done
      )
    )
    eval "$oset"

    local step_ranges=${RB_CLI_OPTS[step-list]:-}
    [[ ! $step_ranges ]] || _rb-compute-steps-range "$step_ranges" ${#RB_STEPS[*]}

    if [[ ${RB_CLI_OPTS[dry-run]:-} ]]; then
        _rb-run-list | awk -F'\t' '$3 == "x" { printf "%3s  %s\n", $1, $2 }'
        exit
    fi

    # Let the runbook validate the env vars it expects before running anything.
    if declare -F rb-validate-env >/dev/null; then
        rb-validate-env
    fi

    RB_EXIT_CMDS+=(rb-show-total-runtime rb-show-run-summary)

    [[ ${RB_LOG_FROM_START:-} ]] || rb-start-logging
    rb-run-tasks
    RB_RUN_DONE=x
}

# ---- Utility functions that tasks can use ----------------------------------

Runbook/confirm-continue-task () {
    [[ ${RB_CLI_OPTS[yes]:-} || $$ == $BASHPID ]] || {
        rb-error "$FUNCNAME doesn't work in a subshell! Exiting ..."
        kill $BASHPID
    }
    if ! _rb-ask-yes-skip-quit "Continue ${FUNCNAME[1]}"; then
        rb-info "*** Skipping the rest of ${FUNCNAME[1]} ***"
        continue  # the loop in rb-run-tasks (see shopt compat43)
    fi
}
# ----------------------------------------------------------------------------

# Process Runbook.md specific CLI options
rb-parse-options "$@"; set -- "${RB_CLI_ARGS[@]}"

if [[ ${RB_LOG_FROM_START:-} ]]; then
    rb-start-logging
fi
