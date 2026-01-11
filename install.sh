#!/usr/bin/env bash

set -eE
trap "_log --error 'Failed to install monkeypatch'" ERR

SOURCE_DIR="$(dirname ${BASH_SOURCE[0]})"
source "$SOURCE_DIR/common.sh"

function copy_source_code() {
    rsync -a --exclude='.git' "$SOURCE_DIR/" "$MON_DIR"

    # Add `registered` directory
    mkdir "$MON_DIR/registered"

    _log "Copied source code to $MON_DIR"

}

function setup_monrc_file() {
    # Create monkeypatsh rc file
    touch "$MONRC_FILE"
    echo "export EDITOR" >>"$MONRC_FILE"

    # Source completions
    echo "if [ -d $MON_COMPLETIONS ]; then source <(cat $MON_COMPLETIONS/*); fi" >>"$MONRC_FILE"

    echo "" >>"$MONRC_FILE"

    _log "Created "$MONRC_FILE" file"
}

function add_monconfig_file() {
    cat <<-EOF >"$MON_CONFIG_FILE"
	# Add your configs here
	# Lines starting with '#' are comments
	# editor = vim
	EOF

    _log "Created empty "$MON_CONFIG_FILE" file"
}

function setup_shellrc_file() {
    echo "# Source monkeypatsh" >>"$SHRC_FILE"

    # Since the the aliases definition and PATH variables are in the monkeypatsh rc file
    # and not in the shell rc file, always source it on start up
    echo "if [ -f $MONRC_FILE ]; then source $MONRC_FILE; fi" >>"$SHRC_FILE"

    # Monkeypatsh is itself an alias.
    # Each call to `mon` sources the monkeypatsh rc file to make commands
    # aliases up to date on each monkeypatsh registration and patch.
    echo "alias mon='source "$MONRC_FILE" > $DEVNULL && $MON_DIR/monkeypat.sh'" >>"$SHRC_FILE"

    _log "Configured "$SHRC_FILE" file"

}

echo "Installing monkeypatsh..."
copy_source_code
setup_monrc_file
add_monconfig_file
setup_shellrc_file
echo "Monkeypatsh has been installed successfully."
echo "Refresh your session and run 'mon --help'."
