#!/usr/bin/env bash

function _mon_default() {
    echo "mon: {{cmd}}: default execution not implemented" >&2
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

function _main() {
    local opt="$(_clean_opt $1)"
    case "$opt" in
    '')
        _mon_default "$@"
        ;;
    *)
        if [[ "$opt" == -* ]]; then local kind='option'; else local kind='command'; fi
        echo "mon: {{cmd}}: '$opt' is not a foo $kind" >&2
        return 1
        ;;
    esac
}

if [[ "$0" = "${BASH_SOURCE[0]}" ]]; then
    _main "$@"
fi
