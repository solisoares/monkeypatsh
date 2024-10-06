#!/usr/bin/bash

function _default() {
    # This guarantee the original command still works as intended.
    if which \${original_cmd} >/dev/null 2>&1; then
        if [ -z "$@" ]; then
            shift
        fi
        \${original_cmd} "$@";
    fi
}

sub_cmd="$@"
case "$sub_cmd" in
    *)
        _default "$sub_cmd"
    ;;
esac
