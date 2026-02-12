MON_DIR=~/.mon

MON_TEMPLATES=$MON_DIR/_templates
MON_REGISTERED=$MON_DIR/registered
MON_REGISTERED_ALIAS=$MON_REGISTERED/alias
MON_REGISTERED_BIN=$MON_REGISTERED/bin
MON_COMPLETIONS=$MON_DIR/completions
MON_TO_UNALIAS=$MON_DIR/.to_unalias
MON_TO_UNHASH=$MON_DIR/.to_unhash

# Aliases to the wrappers and appended PATH variables
# This is used to avoid clutter in the shell rc file
MON_RC_FILE=~/.monrc

SHELL_RC_FILE=~/.bashrc
if [[ "$SHELL" =~ .*zsh.* ]]; then
    SHELL_RC_FILE=~/.zshrc
fi

MON_CONFIG_FILE=~/.monconfig

DEVNULL=/dev/null

RED='\033[0;31m'
GREEN='\033[0;32m'
RESET_COLOR='\033[0m'

function _log() {
    message="[${GREEN}OK${RESET_COLOR}] $@"

    if [ "$1" = '--error' ]; then
        shift
        message="[${RED}ERROR${RESET_COLOR}] $@"
    fi

    echo -e "$message"
}
