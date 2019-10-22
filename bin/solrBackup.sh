#!/bin/bash

# SOLR Backup script
# Backup all solr collection, and gzip old backup data
# Backup dir default: /var/backups/solr/[[:solrHost:]]//[[:collection:]]
# Should be run on local solr nodes, because solr only backup local

SELF="${BASH_SOURCE[0]##*/}"
NAME="${SELF%.sh}"

OPTS="d:u:c:svxEh"
USAGE="Usage: $SELF [$OPTS]"

HELP="
$USAGE

    Options:
        -d      Backupdir
        -u      Solr Host (list seperated by ,)
        -c      Collection (list seperated by ,)
        -s      simulate
        -v      set -v
        -x      set -x
        -e      set -ve
        -h      Help

    The backups will be saved under Backupdir/solrHost/collection
    Backup file name format: year,month,dat+Timestamp

"

quit (){
    local retCode="$1" msg="${*:2}"

    printf '%s\n' "$msg"
    exit $retCode
}

[[ "$BASH_VERSION" =~ ^5.* ]] || EPOCHSECONDS="$(date +%s)"
date="$( date +%Y%m%d )"

_backupDir="/var/backups/solr"

while getopts "${OPTS}" arg; do
    case "${arg}" in
        d) _backupDir="${OPTARG}"                                       ;;
        u) IFS=',' read -a _solrHost <<<"$OPTARG"                       ;;
        c) IFS=',' read -a _collections <<<"$OPTARG"                    ;;
        v) set -v                                                       ;;
        x) set -x                                                       ;;
        e) set -ve                                                      ;;
        h) quit 0 "$HELP"                                               ;;
        ?) quit 1 "Invalid Argument: $USAGE"                            ;;
        *) quit 1 "$USAGE"                                              ;;
    esac
done
shift $((OPTIND - 1))

shopt -s extglob
shopt -s nullglob

# Check if backupdir exist
[[ -d "$_backupDir" ]] || quit 2 "Backup ($_backupDir) does not exist"

# Backup collections of all solr host
for host in "${_solrHost[@]}"; do
    
    [[ "${host%/}/" =~ http.*//(.*)/ ]] && reqHost="${BASH_REMATCH[1]}"
    reqHost="${reqHost%%:*}"

    [[ -z "$reqHost" ]] && continue

    # Check if collection are specified by the user, if not get the list of all collections
    if [[ -z "$_collections" ]]; then
        collectionJson="$(curl -s -X GET "${host%/}/api/cluster")"
        [[ -z "$collectionJson" ]] && continue
        _collections=($(printf '%s' "$collectionJson" | jq -r '.collections[]'))
    fi     
    
    for collection in "${_collections[@]}"; do
        if ! [[ -d "$_backupDir/$reqHost/$collection" ]]; then
            mkdir -p $_backupDir/$reqHost/$collection || quit 2 "Could not create backupDir ($_backupDir/$reqHost/$collection)"
        fi

        # Gzip old backupData
        # XXX: We should replace by tar
        #for file in "$_backupDir/$reqHost/$collection/!(*.gz)"; do
        #    gzip $file
        #done
    
        # Run backup curl
        responseJson="$(curl -s -X GET "${host%/}/solr/admin/collections?action=BACKUP&name=$date.$EPOCHSECONDS&backup&collection=$collection&location=$_backupDir/$reqHost/$collection")"
        
        if ! [[ "$(printf '%s' "$responseJson" | jq -r '.responseHeader.status')" == "0" ]]; then
            quit 2 "Backup failed on $host collection $collection"
        fi
        printf 'Backup started on %s collection %s in %s/%s/%s/%s.%s' "$host" "$collection" "$_backupDir" "$reqHost" "$collection" "$date" "$EPOCHSECONDS"

    done
done
