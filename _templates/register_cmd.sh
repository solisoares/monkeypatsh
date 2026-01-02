#!/usr/bin/env bash

function _default() {
    if which \${cmd} >/dev/null 2>&1; then
        # Guarantee the original command still works as intended.
        \${cmd} "$@"
    else
        : # Change this if you are creating a new command from scratch
    fi
}

_opt="$1"
case "$_opt" in
*)
    _default "$@"
    ;;
esac
