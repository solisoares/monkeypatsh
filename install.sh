#!/usr/bin/env bash

set -eE
trap '_log --error "Failed to install monkeypatsh"' ERR

SOURCE_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))"
source "$SOURCE_DIR/common.sh"

function copy_source_code() {
    local msg

    if [[ -d "$MON_DIR" ]]; then
        echo "$0: line $LINENO: destination already exist"
        return 1
    fi

    if [ "$devmode" -eq 1 ]; then
        # Dev install: symlink source
        ln -s "$SOURCE_DIR/" "$MON_DIR"
        msg="Symlinked source code to: $MON_DIR"
    else
        # Normal install: copy source
        rsync -a --exclude='.git' "$SOURCE_DIR/" "$MON_DIR"
        msg="Copied source code to: $MON_DIR"
    fi

    # Add directories for registered commands
    #   bin  : accessible by PATH variable, directly available in scripts, good for new commands.
    #   alias: aliases, good for patching existent commands like git, ls, ...
    mkdir -p "$MON_REGISTERED_BIN"
    mkdir -p "$MON_REGISTERED_ALIAS"

    _log "$msg"

}

function setup_monrc_file() {
    _render "$MON_TEMPLATES/setup_monrc.sh" \
        'MON_DIR' 'MON_REGISTERED_BIN' 'MON_COMPLETIONS_BASH' 'MON_COMPLETIONS_ZSH' 'MON_BIN' 'MON_RC_FILE' 'MON_TO_UNALIAS' 'MON_TO_UNALIAS' 'MON_TO_UNHASH' 'MON_TO_REFRESH_COMPLETION' \
        "$MON_DIR" "$MON_REGISTERED_BIN" "$MON_COMPLETIONS_BASH" "$MON_COMPLETIONS_ZSH" "$MON_BIN" "$MON_RC_FILE" "$MON_TO_UNALIAS" "$MON_TO_UNALIAS" "$MON_TO_UNHASH" "$MON_TO_REFRESH_COMPLETION" \
        >"$MON_RC_FILE"

    _log "Created file: $MON_RC_FILE"
}

function add_monconfig_file() {
    _render "$MON_TEMPLATES/monconfig.sh" >"$MON_CONFIG_FILE"

    _log "Created file: $MON_CONFIG_FILE"
}

function setup_shellrc_files() {
    for shell_rc_file in "${SHELL_RC_FILES[@]}"; do
        echo "" >>"$shell_rc_file"

        # Since the the aliases definition and PATH variables are in the monkeypatsh rc file
        # and not in the shell rc file, always source it on start up
        echo "if [ -f $MON_RC_FILE ]; then source $MON_RC_FILE; fi" >>"$shell_rc_file"

        _log "Configured file: $shell_rc_file"
    done
}

devmode=0
if [ "$1" = '--dev' ]; then
    devmode=1
fi

if [[ "${#SHELL_RC_FILES[@]}" -eq 0 ]]; then
    _log --error "Shell $([[ -n "$SHELL" ]] && echo \'"$SHELL"\')not supported."
    echo 'Aborting...'
    exit 1
fi

logo="\
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░███████░░░░░░
░█▐█░█▀█░█▀█░█░█░█▀▀░█░█░█▀█░█▀█░▀█▀░██░▄▄██░█░█░░
░█▐█░█░█░█░█░█▀▄░█▀▀░▀█▀░█▀▀░█▀█░░█░░██▄▄░██░█▀█░░
░▀░▀░▀▀▀░▀░▀░▀░▀░▀▀▀░░▀░░▀░░░▀░▀░░▀░░██▄▄▄█▀░▀░▀░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▀▀▀▀▀▀░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
"

echo "$logo"
echo "Installing monkeypatsh..."

copy_source_code
setup_monrc_file
add_monconfig_file
setup_shellrc_files

echo "✓ Monkeypatsh has been installed successfully."
echo "➔ Refresh your session to apply changes."
