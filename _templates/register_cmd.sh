#!/usr/bin/env bash

function _default() {
    : # add here default execution
}

function __clean_opt() {
    local opt="$1"

    # If multiflag (-<flag1><flag2>...), sort and remove duplicates
    if [[ "${#opt}" -ge 3 && "${opt:0:1}" = '-' && "${opt:1:1}" != '-' ]]; then
        echo "$opt" | grep -o . | sort | tr -d '\n' | tr -s 'a-zA-Z0-9'
    else
        echo "$opt"
    fi
}

_opt="$(__clean_opt $1)"
case "$_opt" in
*)
    _default "$@"
    ;;
esac
