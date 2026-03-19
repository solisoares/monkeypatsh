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
        msg="Symlinked source code to $MON_DIR"
    else
        # Normal install: copy source
        rsync -a --exclude='.git' "$SOURCE_DIR/" "$MON_DIR"
        msg="Copied source code to $MON_DIR"
    fi

    # Add directories for registered commands
    #   bin  : accessible by PATH variable, directly available in scripts, good for new commands.
    #   alias: aliases, good for patching existent commands like git, ls, ...
    mkdir -p "$MON_REGISTERED_BIN"
    mkdir -p "$MON_REGISTERED_ALIAS"

    _log "$msg"

}

function setup_monrc_file() {
    # Create monkeypatsh rc file
    touch "$MON_RC_FILE"

    echo "# The following is here to avoid clutter in the main rc file" >>"$MON_RC_FILE"

    # The `mon` command is itself an alias.
    # Each call to `mon` sources the monkeypatsh rc file to make aliases up
    # to date on each monkeypatsh registration.
    echo "alias mon='source "$MON_RC_FILE"; $MON_BIN'" >>"$MON_RC_FILE"

    # Export monkeypat.sh so we can reference it in completion functions
    echo "if ! echo \"\$PATH\" | grep -q mon; then export PATH=\"$MON_DIR/src/:\$PATH\"; fi" >>"$MON_RC_FILE"

    # For commands registered as binary, export PATH so they can be found
    echo "if ! echo \"\$PATH\" | grep -q mon; then export PATH=\"$MON_REGISTERED_BIN:\$PATH\"; fi" >>"$MON_RC_FILE"

    echo "export EDITOR" >>"$MON_RC_FILE"
    echo "" >>"$MON_RC_FILE"

    echo "# The following is here to be refreshed on every registration (it actually refreshes on on every \`mon\` call)" >>"$MON_RC_FILE"

    # Source completions
    echo "if [[ -d $MON_COMPLETIONS_BASH && -n \$BASH ]]; then for file in $MON_COMPLETIONS_BASH/*; do source \"\$file\"; done; fi" >>"$MON_RC_FILE"
    echo "if [[ -d $MON_COMPLETIONS_ZSH && -n \$ZSH_NAME ]]; then for file in $MON_COMPLETIONS_ZSH/*; do source \"\$file\"; done; fi" >>"$MON_RC_FILE"

    # Unalias pending unregistered alias
    echo "if [[ -f $MON_TO_UNALIAS ]]; then unalias \$(cat $MON_TO_UNALIAS) > /dev/null 2>&1 && rm $MON_TO_UNALIAS; fi" >>"$MON_RC_FILE"
    # Unhash pending unregistered binaries
    echo "if [[ -f $MON_TO_UNHASH ]]; then hash -d \$(cat $MON_TO_UNHASH) > /dev/null 2>&1 && rm $MON_TO_UNHASH; fi" >>"$MON_RC_FILE"

    echo "" >>"$MON_RC_FILE"

    _log "Created "$MON_RC_FILE" file"
}

function add_monconfig_file() {
    cat <<-EOF >"$MON_CONFIG_FILE"
	# Add your configs here
	# Lines starting with '#' are comments
	# editor=vim
	EOF

    _log "Created "$MON_CONFIG_FILE" file"
}

function setup_shellrc_files() {
    for shell_rc_file in "${SHELL_RC_FILES[@]}"; do
        echo "" >>"$shell_rc_file"

        # Since the the aliases definition and PATH variables are in the monkeypatsh rc file
        # and not in the shell rc file, always source it on start up
        echo "if [ -f $MON_RC_FILE ]; then source $MON_RC_FILE; fi" >>"$shell_rc_file"

        _log "Configured "$shell_rc_file" file"
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
