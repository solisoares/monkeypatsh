# Development source code
MON_SOURCE=./monkeypat.sh
MON_SOURCE_CONSTANTS=./constants.sh
MON_SOURCE_UNINSTALL=./uninstall.sh

# Directory with monkeypatsh wrappers for the registered
# commands as well as the monkeypatsh itself (mon)
MON_DIR=~/.mon

# The monkeypatsh executable
MON_BIN=$MON_DIR/mon_

MON_SCRIPTS=$MON_DIR/.scripts

MON_TEMPLATES=$MON_DIR/templates

MON_CONFIG_FILE=~/.monconfig

# Aliases to the wrappers and appended PATH variables
# This is used to avoid clutter in the shell rc file
MONRC_FILE=~/.monrc

SHRC_FILE=~/.bashrc
if [[ "$SHELL" =~ .*zsh.* ]]; then
    SHRC_FILE=~/.zshrc
fi

DEVNULL=/dev/null
