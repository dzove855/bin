#!/bin/bash

SELF="${BASH_SOURCE[0]##*/}"

OPTS="m:u:r:vxEh"
USAGE="Usage: $SELF [$OPTS]"

HELP="
$USAGE

    Options:
        -m      Master key
        -u      url
        -r      request method
        -v      set -v
        -x      set -x
        -E      set -vE
        -h      Help


    For the date you can also setup an env variable AZUREDATE
"

_quit (){
    local retCode="$1" msg="${*:2}"

    printf '%s\n' "$msg"
    exit "$retCode"
}


function createAuthorizationToken() {
    local requestMethod="${1,,}" resourceType="${2,,}" resourceId="${3,,}" date="${4,,}" masterKey="${5}"

    masterKey="$(printf "$masterKey" | base64 --decode | hexdump -v -e '/1 "%02x"')"

    local body="${requestMethod}\n${resourceType}\n${resourceId}\n${date}\n\n"

    local sig="$(printf "$body" | openssl dgst -sha256 -mac hmac -macopt hexkey:$masterKey -binary | base64)"

    printf 'type=master&ver=1.0&sig=%s' "$sig"
}

function urlencode() {
    # Usage: urlencode "string"
    local LC_ALL=C
    for (( i = 0; i < ${#1}; i++ )); do
        : "${1:i:1}"
        case "$_" in
            [a-zA-Z0-9.~_-])
                printf '%s' "$_"
            ;;

            *)
                printf '%%%02X' "'$_"
            ;;
        esac
    done
    printf '\n'
}

while getopts "${OPTS}" arg; do
    case "${arg}" in
        m) masterKey="$OPTARG"                                          ;;
        u) IFS=/ read -ra url <<<"$OPTARG"                              ;;
        r) requestMethod="$OPTARG"                                      ;;
        v) set -v                                                       ;;
        x) set -x                                                       ;;
        E) set -vE                                                      ;;
        h) _quit 0 "$HELP"                                              ;;
        ?) _quit 1 "Invalid Argument: $USAGE"                           ;;
        *) _quit 1 "$USAGE"                                             ;;
    esac
done
shift $((OPTIND - 1))

for value in masterKey url requestMethod; do
    [[ -z "${!value}" ]] && _quit 2 "value is missing"
done 

TZ=GMT printf -v date '%(%a, %d %b %Y %T %Z)T'  -1

date="${AZUREDATE:-$date}"

lastUrlEntry="${url[-1]}"
unset "url[-1]"

for entry in "${url[@]}"; do
    requestUrl+="${entry}/"
done

printf '%s' "$(urlencode "$(createAuthorizationToken "$requestMethod" "$lastUrlEntry" "${requestUrl%/}" "$date" "$masterKey")")"
