#!/bin/bash

SELF="${BASH_SOURCE[0]##*/}"
#shellcheck disable=SC2034
NAME="${SELF%.sh}"

OPTS="l:SsvxEh"
USAGE="Usage: $SELF [$OPTS]"

HELP="
$USAGE

    Options:
        -l      Length
        -S      No special Char
        -s      simulate
        -v      set -v
        -x      set -x
        -E      set -vE
        -h      Help


"

_quit (){
    local retCode="$1" msg="${*:2}"

    printf '%s\n' "$msg"
    exit "$retCode"
}

lastChar="12"

while getopts "${OPTS}" arg; do
    #shellcheck disable=SC2034
    case "${arg}" in
        l) lastChar="$OPTARG"                                           ;;
        S) noSpecial="1"                                                ;;
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

set -o noglob

alphaArr=({a..z} {A..Z})
numArr=({0..9})
specialArr=("+" "-" "_" "." "!" "(" ")" "?" "," "=" "~" "/" '\' "&" "|" "@" "^" "$" "]" "[" '*' '`' '"' '´' "%" "{" "}" "<" ">")

alphaNumArr=(${alphaArr[@]} ${numArr[@]})
allCharArr=(${alphaNumArr[@]} ${specialArr[@]})

for ((number=1;number<=lastChar;number++)); do
    if [[ "$number" == @(1|$lastChar) ]]; then
        password+="${alphaNumArr[$RANDOM % ${#alphaNumArr[@]}]}"
    else
        if [[ -z "$noSpecial" ]]; then
            password+="${allCharArr[$RANDOM % ${#allCharArr[@]}]}"
        else
            password+="${alphaNumArr[$RANDOM % ${#alphaNumArr[@]}]}"
        fi
    fi
done

printf '%s\n' "$password"
                                
