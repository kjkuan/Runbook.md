#TODOs:
#  - Add an option to submit the runbook as an github issue or gist?
#    This would make it easier to view (and be reviewed); plus, checkboxes
#    can then be toggled!
#  - Add an option to resume from the last failed task.

# If we are being sourced and told to RUN the sourcing doc
if [[ $0 != "$BASH_SOURCE" && $1 == RUN ]]; then
    shift # the 'RUN'

    # Save the STDIN for later use by the runbook
    exec {RB_STDIN}<&0; export RB_STDIN

    # Invert the Markdown text and the Bash examples in the document, turning it
    # into a Bash script with the examples as code and everything else as comments.
    awk '
        /^```/             { print "#", $0; in_code += 1; next }
        in_code % 2 == 0   { print "#", $0; next }
        in_code % 2 == 1   { print }
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
        local token1 token2
        while read -r token1 token2 _; do
            [[ $token1 ]] || continue
            [[ $token2 ]] && break
        done < "$file"
        if [[ "$token1 $token2" == '[&>/dev/null; touch' ]]; then
            echo "It looks like $file has already been decorated by Runbook.md."
            chmod +x "$file"
            exit
        fi
        local content; content=$(
            cat <<'HEADER'
[&>/dev/null; touch "!---$$"; : ]: # (Please keep this and the comment below)
<!---$$ &>/dev/null; rm -f "!---$$"
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
#FIXME: check for bash version to support at least Bash 4.3 as well.

# Save the path to the original runbook file as $0
if [[ ${RB_FROM_STDIN:-} ]]; then
    BASH_ARGV0=$(cd "$(dirname "$1")"; echo "$PWD/${1##*/}"); shift
else
    BASH_ARGV0=$(cd "$(dirname "$0")"; echo "$PWD/${0##*/}")
fi

RB_LOG_DIR=$PWD/log
RB_EXIT_CMDS=()
RB_CLI_ARGS=()
RB_TASKS=()
#RB_LOG_LEVEL=

declare -A RB_CLI_OPTS=([task-regex]=^Task/)
declare -A RB_TASKS_TO_RUN=()

if [[ -t 1 ]]; then
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
    set +x  # so that we do as much clean up as possible.

    # Restore stdout and stderr so that in the case of an interactive Ctrl-C,
    # which would killed the logging child process that we redirected stdout
    # and stderr to, we'd still be able to see some messages.
    [[ ${RB_STDOUT:-} && ${RB_STDERR:-} ]] && exec >&$RB_STDOUT 2>&$RB_STDERR

    rb-info "Exiting and cleaning up ..."
    local i=$(( ${#RB_EXIT_CMDS[*]} - 1))
    for i in $(seq $i -1 0); do eval "${RB_EXIT_CMDS[$i]}"; done
    rb-info "Done."
}
trap rb-run-exit-commands EXIT

_rb-tstamp-lines () {
    local tfmt=${1:?} line
    while IFS='' read -r line; do
        printf "%($tfmt)T %s\n" -1 "$line"
    done
}
rb-start-logging () {
    exec {RB_STDOUT}>&1 {RB_STDERR}>&2
    mkdir -p "$RB_LOG_DIR"; RB_LOG_DIR=$(cd "$RB_LOG_DIR" && pwd)
    local tfmt=%Y-%m-%dT%T
    local logfd tstamp=$(date +$tfmt)
    rb-info "Detailed runbook logs can be found in $RB_LOG_DIR/"

    local output_log=$RB_LOG_DIR/${0##*/}_$tstamp.log
    local trace_log=$RB_LOG_DIR/${0##*/}_$tstamp.trace
    touch "$output_log" "$trace_log"
    ln -nfs "$output_log" "${output_log%/*}/${0##*/}.log"
    ln -nfs "$trace_log" "${trace_log%/*}/${0##*/}.trace"

    exec {logfd}> >(_rb-tstamp-lines $tfmt > "$trace_log")
    BASH_XTRACEFD=$logfd; set -x
    exec 1> >(exec tee >(_rb-tstamp-lines $tfmt > "$output_log")) 2>&1
}

rb-show-help () {
    cat <<EOF
Usage: $0 [options] [args]
Options:
    -h, --help        Show this help.

    -l, --list-tasks  List all tasks in the order they are defined in the runbook.

    -t LIST           Run only tasks specified by LIST, which is a list of comma
                      separated task indexes (as shown with option '-l') and/or
                      index ranges of the following forms: (similar to 'cut -f LIST')

                        0     A special case that skips all tasks.
                        N     The N-th task.
                        N-    From the N-th task to the last task.
                        N-M   From the N-th task to the M-th task. (M >= N)
                        -M    From the first task to the M-th task.
                        NAME  Name of the task function to be executed.

    -y, --yes         Say yes to all task confirmation prompts.

    --                Pass the rest of CLI args to the runbook.

    --log-dir DIR     Save log files to DIR (Defaults to ./log).    
    --log-from-start  Start logging at the start of the runbook script's execution.
                      (Default is to start logging only when task execution starts)

    --task-regex RE   Make any function defined directly in the runbook and
                      matching the regex RE a task function. RE defaults to ^Task/

EOF
}
# Process runbook CLI options; remaining args will be put in the RB_CLI_ARGS array.
#
rb-parse-options () {   # "$@"
    while (( $# )); do
        local opt=$1; shift
        case $opt in
          -h|--help      ) rb-show-help; exit ;;
          -l|--list-tasks) RB_CLI_OPTS[list-tasks]=x ;;
          -t|--tasks     ) RB_CLI_OPTS[task-list]=$1
                           shift || { rb-show-help >&2; rb-fail; }
                           ;;
          -y|--yes       ) RB_CLI_OPTS[yes]=x ;;
          --log-dir      ) RB_LOG_DIR=$1
                           shift || { rb-show-help >&2; rb-fail; }
                           ;;
          --log-from-start) RB_CLI_OPTS[log-from-start]=x ;;
          --task-regex    ) RB_CLI_OPTS[task-regex]=$1
                            shift || { rb-show-help >&2; rb-fail; }
                            ;;
          --) RB_CLI_ARGS=("$@"); break ;;
          -*) rb-show-help >&2; rb-error "Unknown option: $opt"; rb-fail ;;
           *) RB_CLI_ARGS=("$opt" "$@"); break ;;
        esac
    done
}

_rb-compute-tasks-range () {
    local range_regex='^(0|[1-9][0-9]*|[1-9][0-9]*-|-[1-9][0-9]*|[1-9][0-9]*-[1-9][0-9]*)$'
    local range ranges; readarray -td, ranges < <(echo -n "${1:?}")
    local task_count=${2:?}
    local task_names; task_names=$(rb-list-tasks)
    for range in "${ranges[@]}"; do
        [[ $range =~ $range_regex ]] || {
            # might be a task function name
            local r=$(set +o pipefail; fgrep -m1 -xn "$range" <<<"$task_names" | cut -d: -f1)
            if [[ ! $r ]]; then
                rb-error "Invalid task range spec: ${range}"
                rb-fail
            else
                range=$r
            fi
        }
        IFS=- read -r low high <<<"$range"
        if [[ $range != *-* ]]; then
            RB_TASKS_TO_RUN[$low]=x
        else
            [[ $high ]] || high=$task_count
            [[ $low  ]] || low=1
            (( low <= high )) || {
                rb-error "Invalid decreasing task range: $range"
                rb-fail
            }
            local i
            for ((i=$low; i<=$high; i++)); do
                RB_TASKS_TO_RUN[$i]=x
            done
        fi
    done
}

rb-list-tasks () (
    local func_names; func_names=$(
        declare -F \
          | while read -r line; do echo "${line##* }"; done \
          | egrep "${RB_CLI_OPTS[task-regex]:?}" || true
    )
    [[ $func_names ]] || return 0

    # To get the line number where a function is defined.
    set -f; shopt -s extdebug

    declare -F $func_names \
      | sort -nk2,2 \
      | cut -d' ' -f1
)

# Run the Task functions in their definition order.
#
rb-run-tasks () {
    local i=0 task
    for task in "${RB_TASKS[@]}"; do
        (( ++i ))
        if [[ ! ${RB_CLI_OPTS[task-list]:-} || ${RB_TASKS_TO_RUN[$i]:-} ]]; then
            rb-info "${RB_YELLOW}=== Executing $task (task $i) =========================="
            "$task"
            rb-info "${RB_GREEN}=== Successfully executed $task (task $i) =============="
        else
            rb-info "*** Skipped $task due to unspecified task nubmer: $i ***"
        fi
    done
}

# Main entry point to be called at the end of the runbook to
# handle runbook options and start running tasks.
rb-main () {
    if [[ ${RB_CLI_OPTS[list-tasks]:-} ]]; then
        rb-list-tasks | nl; return
    fi

    set -f; RB_TASKS=($(rb-list-tasks)); set +f
    local task_ranges=${RB_CLI_OPTS[task-list]:-}
    [[ ! $task_ranges ]] || _rb-compute-tasks-range "$task_ranges" ${#RB_TASKS[*]}

    [[ ${RB_CLI_OPTS[log-from-start]:-} ]] || rb-start-logging
    rb-run-tasks
}

# ---- Utility functions that tasks can use ----------------------------------

Runbook/confirm-continue-task () {
    [[ ! ${RB_CLI_OPTS[yes]:-} ]] || return 0

    [[ $$ == $BASHPID ]] || {
        rb-error "$FUNCNAME doesn't work in a subshell! Exiting ..."
        kill $BASHPID
    } >&2
    local ans
    while true; do
        read -u ${RB_STDIN:?} -rp "Runbook.md: Continue ${FUNCNAME[1]} ([Y]es/[S]kip/[Q]uit)? " ans
        case ${ans,,} in
          y|yes ) break ;;
          s|skip) rb-info "*** Skipping the rest of ${FUNCNAME[1]} ***"; continue 2 ;;
          q|quit) exit ;;
               *) continue ;;
        esac
    done
}
# ----------------------------------------------------------------------------

# Process Runbook.md specific CLI options
rb-parse-options "$@"; set -- "${RB_CLI_ARGS[@]}"

if [[ ${RB_CLI_OPTS[log-from-start]:-} ]]; then
    rb-start-logging
fi
