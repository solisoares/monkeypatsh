#!/usr/bin/env bash

function _default() {
	\${cmd} "$@" # default execution
}

_opt="$1"
case "$_opt" in
*)
    _default "$@"
    ;;
esac
