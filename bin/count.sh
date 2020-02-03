#!/bin/bash

SELF="${BASH_SOURCE[0]##*/}"

OPTS="d:m:f:DSrvxEh"
USAGE="Usage: $SELF [$OPTS] dir1 dir2 ..."

HELP="
$USAGE

    Options:
        -S      Super glob (**)
        -r      Recursive 
        -m      Max depth (with -r)
        -d      exclude dir
        -f      exclude symlinks (not implemented)
        -D      Disable Dot Files
        -s      Simulate
        -v      set -v
        -x      set -x
        -E      set -vE
        -h      Help


    NOTE: Do not set final / in dir name

"

_quit(){
    local retCode="$1" msg="${*:2}"

    printf '%s\n' "$msg"
    exit "$retCode"
}

_count(){
    local dir="$1" numFiles _regex="$2"
    #shellcheck disable=SC2206
    numFiles=("${dir%/}"/$_regex)
    printf "%s %s\n" "${dir%/}" "${#numFiles[@]}"
}

# default dir
dirs=("./")
regex="*"

shopt -s nullglob
shopt -s extglob
shopt -s globstar
shopt -s dotglob

while getopts "${OPTS}" arg; do
    case "${arg}" in
        r) find=1; opts+="-type d"                                              ;;
        m) maxdepth="-maxdepth ${OPTARG}"                                       ;;
        d) regex="!(${OPTARG})" prune="1" exclude="$OPTARG"                     ;;
        # XXX: Not implemented yet
        #f) exclude_symlink=1                                                    ;;
        S) superGlob=1                                                          ;;
        D) shopt -u dotglob; prune="1"; exclude="/."                            ;;
        v) set -v                                                               ;;
        x) set -x                                                               ;;
        E) set -vE                                                              ;;
        h) _quit 0 "$HELP"                                                      ;;
        ?) _quit 1 "Invalid Argument: $USAGE"                                   ;;
        *) _quit 1 "$USAGE"                                                     ;;
    esac
done
shift $((OPTIND - 1))

(( $# )) && read -ra dirs <<<"$*"


# Run Commands for each dir
for dir in "${dirs[@]}"; do
    #Super glob
    if (( superGlob )); then
        regex="**"
        _count "${dir}" "$regex"
    # check if find is defined
    elif (( find )); then
        if (( prune )); then
            while read -r subDir; do
                # Run count on subdirs
                _count "$subDir" "*"
            done < <(find "$dir" "$maxdepth" -not -path "*$exclude*" "$opts")
        else
            while read -r subDir; do
                # Run count on subdirs
                _count "$subDir" "*"
            done < <(find "$dir" "$maxdepth" "$opts")
        fi
    else
        # run count on current dir
        _count "$dir" "$regex"
    fi
done
