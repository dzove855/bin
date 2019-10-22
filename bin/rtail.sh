#!/bin/bash

SELF="${BASH_SOURCE[0]##*/}"
NAME="${SELF%.sh}"

OPTS="H:f:svxEh"
USAGE="Usage: $SELF [$OPTS]"

HELP="
Tail on multiple remote hosts

$USAGE

    Options:
        -H      Host (Comma seperated list)
        -f      Files (Comma seperated list)
        -s      simulate
        -v      set -v
        -x      set -x
        -E      set -vE
        -h      Help


    Example:
        $SELF -H srv1,srv2 -f /var/log/haproxy.log

"

_quit (){
    local retCode="$1" msg="${@:2}"

    printf '%s\n' "$msg"
    exit $retCode
}

_exit(){
    rm ${tmpFiles[@]}
    kill ${pids[@]}
}

while getopts "${OPTS}" arg; do
    case "${arg}" in
        H) IFS=',' read -a hosts <<<"$OPTARG"                           ;;
        f) IFS=',' read -a files <<<"$OPTARG"                           ;;
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

[[ -z "$host" || -z "$files" ]] && _quit 2 "$HELP"

trap '_exit' EXIT

for host in "${hosts[@]}"; do
    random="$RANDOM"
    tmpFiles+=("/tmp/$host.$random")
    ssh -tt $host "sudo tail -f ${files[@]}" >> /tmp/$host.$random &
    pids+=("$!")
done

tail -f ${tmpFiles[@]}

