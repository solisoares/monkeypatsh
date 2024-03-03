MON_SOURCE=./monkeypat.sh

LOCAL_MANPATH=~/.local/share/man

# Directory with monkeypatsh wrappers for the registered
# commands as well as the monkeypatsh itself (mon)
MON_DIR=~/.mon

# The monkeypatsh executable
MON_BIN=$MON_DIR/mon

# Aliases to the wrappers and appended PATH and MANPATH variables
# This is necessary to avoid clutter in the .rc file
MON_CONFIG_FILE=~/.monconfig

# TODO: support any .rc file
SHRC_FILE=~/.zshrc

DEVNULL=/dev/null
