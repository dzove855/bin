#!/bin/bash

# ansible frontend script
# PDSH is great too, but the idea is to create an ansible based script, with including %h %u
# and rsync simular syntax

SELF="${BASH_SOURCE[0]##*/}"
NAME="${SELF%.sh}"

OPTS="u:i:f:H:t:o:O3abVSRPvxEh"
USAGE="Usage: $SELF [$OPTS]"

HELP="
$USAGE

    Options:
        -3      Use python 3 interpreter
        -f      Ansible --fork (fork how many commands to run in the same time)
        -b      Ansible --become (run command as sudo)
        -u      Ansible --become-user
        -t      Ansible --tree (log output in directly in a filename based on host name)
        -O      Ansible --one-line
        -V      Ansible verbose
        -i      Inventory
        -R      Rsync
        -a      Rsync -a equivalent (ansible: perms=no group=no owner=no times=yes)
        -H      Host
        -S      shell
        -P      Push - Run - Remove
        -o      SSH Options
        -v      set -v
        -x      set -x
        -E      set -vE
        -h      Help

    Expressions:
        %h      Host
        %u      User
        %d      Date (date +%Y.%m.%d)

    Examples:
        rsync
            $SELF -R /tmp/test term.prod:/tmp/fuu
            $SELF -R web.prod:/tmp/fuu /tmp/%h/fuu   

        shell
            $SELF -H HOST -S COMMAND

        push
            $SELF -H HOST -P /path/to/command OPTIONS
"

function do_quit ()
{
    local retCode="$1" msg="${*:2}"

    printf '%s \n' "$msg"
    exit "$retCode"
}

# reset expressions
function _set_expression()
{
    # Declare expressions to use on ad hoc
    declare -A _expressions
    _expressions["%h"]="{{ inventory_hostname }}"
    _expressions["%u"]="{{ ansible_user }}"
    _expressions["%d"]="$(date +%Y.%m.%d)"

    # replace expressions with the correct value
    for key in "${!_expressions[@]}"
    do
        for value in "$@"
        do
            declare -g "${value}"="${!value//$key/${_expressions[$key]}}"
        done
    done
}

# check values if they are set
function _check
{
    for value in "$@"
    do
        [[ -z "${!value}" ]] && do_quit 2 "Value ($value) is not set! $HELP"
    done
}

# Function for -r
function _rsync()
{
    _check _src _dest
    _set_expression _src _dest

    # Check if it is push or pull
    # and set _host
    if [[ "$_src" =~ .+:.* ]]
    then
        _host="${_src%%:*}"
        _src="${_src#*:}"
        _mode="mode=pull"
    elif [[ "$_dest" =~ .+:.* ]]
    then
        _host="${_dest%%:*}"
        _dest="${_dest#*:}"
    fi

    # Set module and options
    _module="synchronize"
    _options+="src='$_src' dest='$_dest' $_mode $_rsync_opts"

    _ansible
}

# Function for -s
function _shell
{
    _check _command
    _set_expression _command

    _module="shell"
    _options+="$_command"

    _ansible
}

function _push
{
    # Push file to Remote
    tmpFile="/tmp/$NAME.$RANDOM"
    _module="synchronize"
    _options+="src='$_src' dest='$tmpFile'"
    _ansible &>/dev/null

    unset _module _options

    # run the command
    _module="shell"
    _options+="bash $tmpFile $_command ; rm $tmpFile"
    _ansible
}

function _ansible
{
    # check if at least on action is set
    _check _host _module _options

    # run ansible
    ansible "$_inventory" "$_host" -m "$_module" -a "$_options" "$_opts" -e "$_vars" --ssh-common-args="$_ssh"
}

# hash ansible
hash -p /usr/bin/ansible ansible || do_quit 2 "CRITICAL: could not hash anisble"

[[ $# -eq 0 ]] && do_quit 2 "Really? $HELP"

while getopts "${OPTS}" arg; do
    case "${arg}" in
        3) _vars+=" ansible_python_interpreter=/usr/bin/python3"        ;;
        f) _opts+=" -f ${OPTARG}"                                       ;;
        b) _opts+=" -b"                                                 ;;
        u) _opts+=" --become-user=${OPTARG}"                            ;;
        t) _opts+=" -t ${OPTARG}"                                       ;;
        i) _inventory="-i ${OPTARG}"                                    ;;
        V) _opts+=" -v"                                                 ;;
        R) _action="_rsync"                                             ;;
        a) _rsync_opts="owner=no group=no perms=no times=yes"           ;;
        S) _action="_shell"                                             ;;
        P) _action="_push"                                              ;;
        H) _host="${OPTARG}"                                            ;;
        o) _ssh+=" ${OPTARG}"                                           ;;
        O) _opts+=" -o"                                                 ;;
        v) set -v                                                       ;;
        x) set -x                                                       ;;
        E) set -vE                                                      ;;
        h) do_quit 0 "$HELP"                                            ;;
        ?) do_quit 1 "Invalid Argument: $USAGE"                         ;;
        *) do_quit 1 "$USAGE"                                           ;;
    esac
done
shift $((OPTIND - 1))

# get what action is set and the define the needed configuration
case "${_action}" in
    _rsync) _src="$1" _dest="$2"                                        ;;
    _shell) _command="$*"                                               ;;
    _push)  _src="$1" _command="${*:2}"                                 ;;
    *) do_quit 2 "$HELP"                                                ;;
esac

# run the action function
$_action
