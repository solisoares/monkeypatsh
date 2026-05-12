#!/usr/bin/env bash

function _clean_opt() {
    local opt="$1"

    # If multiflag (-<flag1><flag2>...), sort and remove duplicates
    if [[ "${#opt}" -ge 3 && "${opt:0:1}" = '-' && "${opt:1:1}" != '-' ]]; then
        echo "$opt" | grep -o . | sort | tr -d '\n' | tr -s 'a-zA-Z0-9'
    else
        echo "$opt"
    fi
}

function _main_mon_{{cmd}}() {
    local opt="$(_clean_opt $1)"
    case "$opt" in
    *)
        if type -t '_mon_default' >/dev/null; then
            _mon_default "$@"
        else
            if [[ "$#" -eq 0 ]]; then
                echo "mon: {{cmd}}: default execution not implemented" >&2
                return 1
            else
                if [[ "$opt" == -* ]]; then local kind='option'; else local kind='command'; fi
                echo "mon: {{cmd}}: '$opt' is not a foo $kind" >&2
                return 1
            fi

        fi
        ;;
    esac
}

if [[ "$0" = "${BASH_SOURCE[0]}" ]]; then
    _main_mon_{{cmd}} "$@"
fi
