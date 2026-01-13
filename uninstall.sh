#!/usr/bin/env bash

set -eE
trap "_log --error 'Failed to uninstall monkeypatch'" ERR

SOURCE_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))"
source $SOURCE_DIR/common.sh

function rm_mondir() {
    # Remove monkeypatsh executable, wrappers and completions

    local msg

    # If we have symlinked (probably a dev install)
    # we remove by parts
    if [ -L "$(echo $MON_DIR | sed 's:/*$::')" ]; then
        # Remove registered folder (not present in source)
        rm -r "$MON_REGISTERED"
        # Remove all completions besides the one for `mon` (`completions/mon` is present in source)
        find "$MON_COMPLETIONS" -type f | grep -v "$MON_COMPLETIONS/mon"  | xargs -I {} rm {}
        # Remove symlink to source
        rm "$MON_DIR"

        msg="Removed symlink to monkeypatsh executable, wrappers and completions."

    # If not, just remove the copy
    else
        rm -r "$MON_DIR"
        msg="Removed monkeypatsh executable, wrappers and completions."
    fi

    _log "$msg"
}

function rm_monrc_file() {
    if [ -f "$MONRC_FILE" ]; then
        rm $MONRC_FILE
        _log "Removed $MONRC_FILE"
    fi
}

function rm_monconfig_file() {
    if [ -f $MON_CONFIG_FILE ]; then
        rm $MON_CONFIG_FILE
        _log "Removed $MON_CONFIG_FILE"
    fi
}

function update_shellrc_file() {
    # Remove setup configs from .rc file
    sed -i '/monrc/d' $SHRC_FILE
    _log "Removed setup configs from $SHRC_FILE"
}

echo "Uninstalling monkeypatsh..."
rm_mondir
rm_monrc_file
rm_monconfig_file
update_shellrc_file
echo "All done. Monkeypatsh has been uninstalled."
