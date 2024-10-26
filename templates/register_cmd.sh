#!/usr/bin/bash

function _default() {
    # This guarantee the original command still works as intended.
    if which \${original_cmd} >/dev/null 2>&1; then
        # Change the code bellow if you want to modify or decorate the default command.
        # Example:
        #   echo 'starting...'
        #   \${original_cmd} "$@";
        #   echo 'ending...'
        \${original_cmd} "$@";
    fi
}

sub_cmd="$1"
case "$sub_cmd" in
    *)
        _default "$@"
    ;;
esac
