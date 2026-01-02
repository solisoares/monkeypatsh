#!/usr/bin/bash

function _default() {
    if which \${cmd} >/dev/null 2>&1; then
        # Guarantee the original command still works as intended.
        \${cmd} "$@"
    else
        : # Change this if you are creating a new command from scratch
    fi
}

opt="$1"
case "$opt" in
*)
    _default "$@"
    ;;
esac
