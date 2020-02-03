#!/bin/bash

SELF="${BASH_SOURCE[0]##*/}"
NAME="${SELF%.sh}"

OPTS="l:L:t:fSsdvxEh"
USAGE="Usage: $SELF [$OPTS]"

HELP="
$USAGE

    Options:
        -l      Custom Lock Dir                                  Default: /var/run/$NAME
        -L      Custom Log Dir                                   Default: /var/log/$NAME
        -f      Force (This will force the remove of lock file)
        -S      Syslog (This will log in syslog all errors)
        -t      Timeout (This will set an timeout to command)    
        -s      simulate
        -v      set -v
        -x      set -x
        -e      set -ve
        -h      Help

"

_quit(){
    local retCode="$1" msg="${*:2}"

    printf '%s' "$msg"
    exit "$retCode"
}

_checkIfLockFileExist(){
    local lockFile="$1"

    # check if lockFile exist
    [[ -f "$lockFile" ]] && return 1

    return 0
}

_checkIfLockDirExist(){
    [[ -d "$lockDir" ]] && return 

    return 1
}

_createLockFile(){
    local lockFile="$1"

    # Create Lock file if lock file does not exist
    : > "$lockFile"
}

_removeLockFile(){
    local lockFile="$1"

    # remove lock file if lock file exist
    rm "$lockFile"
}

lockDir="/var/run/$NAME/"
logDir="/var/log/$NAME/"

# No 
type timeout &>/dev/null || _quit 2 "Timeout No found"

force=0
syslog=0

while getopts "${OPTS}" arg; do
    case "${arg}" in
        l) lockDir="$OPTARG"                                            ;;
        L) logDir="$OPTARG"                                             ;;
        f) force=1                                                      ;;
        S) syslog=1                                                     ;;
        t) timeout="timeout $OPTARG"                                    ;;
        s) run="echo"                                                   ;;
        d) run="echo"                                                   ;;
        v) set -v                                                       ;;
        x) set -x                                                       ;;
        e) set -ve                                                      ;;
        h) _quit 0 "$HELP"                                              ;;
        ?) _quit 1 "Invalid Argument: $USAGE"                           ;;
        *) _quit 1 "$USAGE"                                             ;;
    esac
done
shift $((OPTIND - 1))

# Parse command to get a correct file name
# XXX: Should we add an escape char list?
# shellcheck disable=SC2206
commandUnParsed=($@)
commandParsed="$*"
: "${commandParsed//\//_}"
: "${_//\./_}"
: "${_//[[:space:]]/_}"
commandParsed="${//-/_}"

[[ -z "${commandUnParsed[0]}" ]] && _quit 2 "$HELP"

# Exit if lock Dir does not exist
_checkIfLockDirExist || _quit 2 "Lock Dir ($lockDir) does not exist!"

lockFile="${lockDir%/}/$commandParsed.lock"

# tmpLogfile, content will be sent on the specific logMethod
tmpLogFile="$(mktemp)"

# Remove the lock file on exit
trap 'rm $tmpLogFile' EXIT

if (( force )); then
    _checkIfLockFileExist "$lockFile" || _removeLockFile "$lockFile"
fi

# Exit if lock File Exist
_checkIfLockFileExist "$lockFile" || _quit 2 "Lock file already exist!"

# Create the lock file before command execution
_createLockFile "$lockFile"

# Run the command 
"$run" "$timeout" "${commandUnParsed[@]}" 2>"$tmpLogFile" || printf '%s' "Command timed out after ${timeout//timeout /}" >> "$tmpLogFile"

# Log to syslog if args is specified
if (( syslog )); then
    logger -- "$(<"$tmpLogFile")"
fi

# Check if logDir exist, if yes cp file to logDir
[[ -d "$logDir" ]] && {
    : "$(<"$tmpLogFile")"
    printf '%s\n' "$_" >>"${logDir%/}/$commandParsed.log"
}

# remove lock file
_removeLockFile "$lockFile"

# Exit like a pro
exit
