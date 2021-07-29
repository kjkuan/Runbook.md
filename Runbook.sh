#TODOs:
#  - Add an option to skip all task confirmations.
#  - Add an option to submit the runbook as an github issue or gist?
#    This would make it easier to view (and be reviewed); plus, checkboxes
#    can then be toggled!
#  - Add an option to resume from the last failed task.

# If we are being sourced and told to RUN the sourcing doc
if [[ $0 != "$BASH_SOURCE" && $1 == RUN ]]; then
    shift # the 'RUN'

    # Invert the Markdown text and the Bash examples in the document, turning it
    # into a Bash script with the examples as code and everything else as comments.
    awk '
        /^```/             { print "#", $0; in_code += 1; next }
        in_code % 2 == 0   { print "#", $0; next }
        in_code % 2 == 1   { print }
    ' "$0" \
           |
    if [[ $1 == dump ]]; then  # special case for debugging purposes
        # just show the generated script with lines numbered.
        nl -ba
    else
        # feed the generated script to Bash via STDIN, passing the
        # runbook's path as $1 followed by the rest of CLI args.
        exec bash -s "$0" "$@"
    fi
    exit
fi

set -eEo pipefail
shopt -s inherit_errexit compat43
#FIXME: check for bash version to support at least Bash 4.3 as well.

# Save the path to the original runbook file as $0
BASH_ARGV0=$(cd "$(dirname "$1")"; echo "$PWD/${1##*/}"); shift

RB_LOG_DIR=$PWD/log
RB_EXIT_CMDs=()
RB_CLI_ARGS=()
RB_TASKS=()
#RB_LOG_LEVEL=

declare -A RB_CLI_OPTS=()
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

rb-dump-stack-trace () {
    local rc=$?; trap ERR
    rb-error "--- Stack trace from shell process $BASHPID depth=$BASH_SUBSHELL -------------"
    rb-error "Return status: $rc"
    echo -ne "$RB_RED"
    while caller $((i++)); do :; done \
      |
    while read -r lineno func file; do
        # Use the runbook file if file is 'main', which is the case when reading
        # the script from STDIN.
        [[ $file != main ]] || file=$0

        echo "File $file, line $lineno, in $func ():"
        echo "$(mapfile -tn1 -s $((lineno - 1)) l < "$file"; echo "$l")"
    done
    echo -ne "$RB_NC"
    rb-error "------------------------------------------------------------------------------"
} >&2
trap rb-dump-stack-trace ERR

rb-run-exit-commands () {
    set +x  # so that we do as much clean up as possible.

    # Restore stdout and stderr so that in the case of an interactive Ctrl-C,
    # which would killed the logging child process that we redirected stdout
    # and stderr to, we'd still be able to see some messages.
    [[ $STDOUT && $STDERR ]] && exec >&$STDOUT 2>&$STDERR

    rb-info "Exiting and cleaning up ..."
    local i=$(( ${#RB_EXIT_CMDs[*]} - 1))
    for i in $(seq $i -1 0); do eval "${RB_EXIT_CMDs[$i]}"; done
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
    exec {STDOUT}>&1 {STDERR}>&2
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
                      index ranges of the following forms:

                        N-   From the N-th task to the last task.
                        N-M  From the N-th task to the M-th task. (M >= N)
                        -M   From the first task to the M-th task.

    --                Pass the rest of CLI args to the runbook.

    --log-dir DIR     Save log files to DIR (Defaults to ./log).    
    --log-from-start  Start logging at the start of the runbook script's execution.
                      (Default is to start logging only when task execution starts)

EOF
}
# Process runbook CLI options; remaining args will be put in the RB_CLI_ARGS array.
#
rb-parse-options () {   # "$@"
    while (( $# )); do
        local arg=$1; shift
        case $arg in
          -h|--help      ) rb-show-help; exit ;;
          -l|--list-tasks) RB_CLI_OPTS[list-tasks]=x ;;
          -t|--tasks     ) RB_CLI_OPTS[task-list]=$1; shift ;;

          --log-dir       ) RB_LOG_DIR=$1; shift ;;
          --log-from-start) RB_CLI_OPTS[log-from-start]=x ;;

          --) RB_CLI_ARGS=("$@"); break ;;
          -*) rb-show-help >&2; rb-error "Unknown option: $arg"; return 1 ;;
           *) RB_CLI_ARGS=("$arg" "$@"); break ;;
        esac
    done
}

_rb-compute-tasks-range () {
    local range_regex='^([1-9][0-9]*|[1-9][0-9]*-|-[1-9][0-9]*|[1-9][0-9]*-[1-9][0-9]*)$'
    local range ranges; readarray -td, ranges < <(echo -n "${1:?}")
    local task_count=${2:?}
    for range in "${ranges[@]}"; do
        [[ $range =~ $range_regex ]] || {
            rb-error "Invalid task range spec: ${range}"
            return 1
        }
        IFS=- read -r low high <<<"$range"
        if [[ $range != *-* ]]; then
            RB_TASKS_TO_RUN[$low]=x
        else
            [[ $high ]] || high=$task_count
            [[ $low  ]] || low=1
            (( low <= high )) || {
                rb-error "Invalid decreasing task range: $range"
                return 1
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
          | grep ^Task/ || true
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
    [[ ${RB_CLI_OPTS[log-from-start]:-} ]] || rb-start-logging

    set -f; RB_TASKS=($(rb-list-tasks)); set +f
    local task_ranges=${RB_CLI_OPTS[task-list]:-}
    [[ ! $task_ranges ]] || _rb-compute-tasks-range "$task_ranges" ${#RB_TASKS[*]}

    rb-run-tasks
}

# ---- Utility functions that tasks can use ----------------------------------

Runbook/confirm-continue-task () {
    [[ $$ == $BASHPID ]] || {
        rb-error "$FUNCNAME doesn't work in a subshell! Exiting ..."
        kill $BASHPID
    } >&2
    local ans
    while true; do
        read -rp "Runbook.md: Continue ${FUNCNAME[1]} ([Y]es/[S]kip/[Q]uit)? " ans </dev/tty
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
