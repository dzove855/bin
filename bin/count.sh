#!/bin/bash

SELF="${BASH_SOURCE[0]##*/}"
NAME="${SELF%.sh}"

OPTS="d:m:f:SrsvxEh"
USAGE="Usage: $SELF [$OPTS] dir1 dir2 ..."

HELP="
$USAGE

    Options:
        -S      Super glob (**)
        -r      Recursive 
        -m      Max depth (with -r)
        -d      exclude dir (not implented)
        -f      exclude symlinks (not implemented)
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
    exit $retCode
}

_count(){
    local dir="$1" numfiles n _regex="$2"

    shopt -s nullglob
    shopt -s extglob
    shopt -s globstar

    numfiles=(${dir%/}/$_regex)
    n="${#numfiles[@]}"
    printf "%s : %s\n" "${dir%/}" "$n"
}

# default dir
_dirs=("./")
_regex="*"

while getopts "${OPTS}" arg; do
    case "${arg}" in
        r) _find=1; opts+=" -type d"                                            ;;
        m) _maxdepth=" -maxdepth ${OPTARG}"                                     ;;
        d) _regex="${OPTARG}"                                                   ;;
        f) _exclude_symlink=1                                                   ;;
        S) _superGlob=1                                                         ;;
        s) _run="echo"                                                          ;;
        v) set -v                                                               ;;
        x) set -x                                                               ;;
        E) set -vE                                                              ;;
        h) _quit 0 "$HELP"                                                      ;;
        ?) _quit 1 "Invalid Argument: $USAGE"                                   ;;
        *) _quit 1 "$USAGE"                                                     ;;
    esac
done
shift $((OPTIND - 1))

[[ $# -eq 0 ]] || _dirs=($@)


# Run Commands for each dir
for _dir in "${_dirs[@]}"; do
    #Super glob
    if [[ $_superGlob ]]; then
        _regex="**"
        _count "${_dir}" "$_regex"
    # check if find is defined
    elif [[ $_find ]]; then
        while read -r _sub_dir; do
            # Run count on subdirs
            _count "$_sub_dir" "$_regex"
        done < <(find ${_dir} $_maxdepth $opts)
    else
        # run count on current dir
        _count "${_dir}" "$_regex"
    fi
done
