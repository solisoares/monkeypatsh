# Directory with monkeypatsh wrappers for the registered
# commands as well as the monkeypatsh itself (mon)
MON_DIR=~/.mon

# The monkeypatsh executable
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

RED='\033[0;31m'
GREEN='\033[0;32m'
NOCOLOR='\033[0m'

function _log() {
    message="[${GREEN}OK${NOCOLOR}] $@"

    if [ "$1" = '--error' ]; then
        shift
        message="[${RED}ERROR${NOCOLOR}] $@"
    fi

    echo -e "$message"
}
