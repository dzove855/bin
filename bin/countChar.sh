#!/bin/bash

SELF="${BASH_SOURCE[0]##*/}"
NAME="${SELF%.sh}"

OPTS="svxEh"
USAGE="Usage: $SELF [$OPTS]"

HELP="
$USAGE

    Options:
        -s      simulate
        -v      set -v
        -x      set -x
        -E      set -vE
        -h      Help


"

_quit (){
    local retCode="$1" msg="${@:2}"

    printf '%s\n' "$msg"
    exit $retCode
}

while getopts "${OPTS}" arg; do
    case "${arg}" in
        s) _run="echo"                                                  ;;
        v) set -v                                                       ;;
        x) set -x                                                       ;;
        E) set -vE                                                      ;;
        h) _quit 0 "$HELP"                                              ;;
        ?) _quit 1 "Invalid Argument: $USAGE"                           ;;
        *) _quit 1 "$USAGE"                                             ;;
    esac
done
shift $((OPTIND - 1))

for key in "$@"; do
    echo "$key : ${#key}"
done
