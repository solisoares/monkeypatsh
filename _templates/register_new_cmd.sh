#!/usr/bin/env bash

function _mon_default() {
    _not_implemented_msg
    return 1
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

function _not_found_msg() {
    local opt="$1"
    local kind='command'
    if [[ "$opt" == -* ]]; then kind='option'; fi
    echo "${cmd}: '$_opt' is not a foo $kind"
}

function _not_implemented_msg() {
    local opt="$1"
    if [[ -z "$opt" ]]; then
        echo "mon: ${cmd}: default execution not implemented" >&2
    else
        echo "mon: ${cmd}: '$opt' not implemented" >&2
    fi
}

function _main() {
    _opt="$(_clean_opt $1)"
    case "$_opt" in
    '')
        _mon_default "$@"
        ;;
    *)
        _not_found_msg "$_opt"
        return 1
        ;;
    esac
}

if [[ "$0" = "${BASH_SOURCE[0]}" ]]; then
    _main "$@"
fi
