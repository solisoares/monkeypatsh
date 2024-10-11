#!/usr/bin/bash

function _default() {
    # This guarantee the original command still works as intended.
    if which \${original_cmd} >/dev/null 2>&1; then
        if [ -z "$@" ]; then
            shift
        fi
        # Change the code bellow if you want to modify or decorate the
        # default command. For example:
        #   echo 'starting...'
        #   \${original_cmd} "$@";
        #   echo 'ending...'
        \${original_cmd} $@;
    fi
}

sub_cmd="$1"
shift
case "$sub_cmd" in
    *)
        _default "$sub_cmd"
    ;;
esac
