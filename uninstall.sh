#!/usr/bin/env bash

set -eE
trap '_log --error "Failed to uninstall monkeypatsh"' ERR

SOURCE_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))"
source $SOURCE_DIR/common.sh

function rm_mondir() {
    # Remove monkeypatsh executable, wrappers and completions

    local msg

    # If we have symlinked (probably a dev install)
    # we remove by parts
    if [ -L "$(echo $MON_DIR | sed 's:/*$::')" ]; then
        # Remove stuff not present in source
        rm -rf "$MON_REGISTERED" "$MON_TO_UNALIAS" "$MON_TO_UNHASH" "$MON_TO_REFRESH_COMPLETION"
        # Remove all completions not present in source
        find "$MON_COMPLETIONS_BASH" -type f | grep -v "$MON_COMPLETIONS_BASH/mon" | xargs -I {} rm {}
        find "$MON_COMPLETIONS_ZSH" -type f | grep -v "$MON_COMPLETIONS_ZSH/mon" | xargs -I {} rm {}
        # Remove symlink to source
        rm "$MON_DIR"

        msg="Removed symlink to: $MON_DIR"

    # If not, just remove the copy
    else
        rm -r "$MON_DIR"
        msg="Removed monkeypatsh directory: $MON_DIR"
    fi

    _log "$msg"
}

function rm_monrc_file() {
    if [ -f "$MON_RC_FILE" ]; then
        rm $MON_RC_FILE
        _log "Removed file: $MON_RC_FILE"
    fi
}

function rm_monconfig_file() {
    if [ -f $MON_CONFIG_FILE ]; then
        rm $MON_CONFIG_FILE
        _log "Removed file: $MON_CONFIG_FILE"
    fi
}

function update_shellrc_files() {
    for shell_rc_file in "${SHELL_RC_FILES[@]}"; do
        # Remove setup configs from .rc file
        local sed_flags=("-i")
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed_flags=("-i" "")
        fi
        sed "${sed_flags[@]}" '/monkeypatsh/d' $shell_rc_file
        sed "${sed_flags[@]}" '/monrc/d' $shell_rc_file
        sed "${sed_flags[@]}" '\|.mon/registered/bin|d' $shell_rc_file
        _log "Removed setup configs from: $shell_rc_file"
    done
}

echo "Uninstalling monkeypatsh..."
rm_mondir
rm_monrc_file
rm_monconfig_file
update_shellrc_files
echo "✓ Monkeypatsh has been uninstalled successfully."
echo "➔ Refresh your session to apply changes."
