#!/usr/bin/env bash

function _mon_default() {
    \${cmd} "$@" # default execution
}

function _clean_opt() {
    local opt="$1"

    # If multiflag (-<flag1><flag2>...), sort and remove duplicates
    if [[ "${#opt}" -ge 3 && "${opt:0:1}" = '-' && "${opt:1:1}" != '-' ]]; then
        echo "$opt" | grep -o . | sort | tr -d '\n' | tr -s 'a-zA-Z0-9'
    else
        echo "$opt"
    fi
}

_opt="$(_clean_opt $1)"
case "$_opt" in
*)
    _mon_default "$@"
    ;;
esac
