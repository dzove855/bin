#!/bin/bash

SELF="${BASH_SOURCE[0]##*/}"

OPTS="S:n:c:vxEh"
USAGE="Usage: $SELF [$OPTS]"

HELP="
$USAGE

    Options:
        -S      Server/Port
        -n      Nickname
        -c      Channel
        -s      simulate
        -v      set -v
        -x      set -x
        -e      set -ve
        -h      Help

"

function _quit ()
{
    local retCode="$1" msg="${*:2}"

    printf '%s\n' "$msg"
    exit "$retCode"
}

declare -i _port

while getopts "${OPTS}" arg; do
    case "${arg}" in
        S) _server="${OPTARG%%/*}" _port="${OPTARG#*/}"                 ;;
        n) _nickname="${OPTARG}"                                        ;;
        c) _channel="${OPTARG}"                                         ;;
        v) set -v                                                       ;;
        x) set -x                                                       ;;
        e) set -ve                                                      ;;
        h) _quit 0 "$HELP"                                              ;;
        ?) _quit 1 "Invalid Argument: $USAGE"                           ;;
        *) _quit 1 "$USAGE"                                             ;;
    esac
done
shift $((OPTIND - 1))

[[ -z "$_server" ]] && _quit 2 "No server! $USAGE"
[[ -z "$_nickname" ]] && _quit 2 "No Nickname! $USAGE"
[[ -z "$_channel" ]] && _quit 2 "No Channel! $USAGE"

[[ -z "$_port" ]] && _port="6667"

message="${*:-/dev/stdin}"

exec 5>/dev/tcp/"$_server"/"$_port"

echo "NICK $_nickname" >&5
echo "USER $_nickname 8 *: $_nickname" >&5
echo "JOIN #$_channel" >&5

echo "PRIVMSG #$_channel $message" >&5
echo "QUIT" >&5

cat <&5
