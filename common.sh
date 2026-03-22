MON_DIR=~/.mon

MON_TEMPLATES=$MON_DIR/_templates
MON_TEMPLATES_COMPLETIONS_BASH=$MON_TEMPLATES/completions/bash
MON_TEMPLATES_COMPLETIONS_ZSH=$MON_TEMPLATES/completions/zsh
MON_REGISTERED=$MON_DIR/registered
MON_REGISTERED_ALIAS=$MON_REGISTERED/alias
MON_REGISTERED_BIN=$MON_REGISTERED/bin
MON_COMPLETIONS=$MON_DIR/completions
MON_COMPLETIONS_BASH=$MON_DIR/completions/bash
MON_COMPLETIONS_ZSH=$MON_DIR/completions/zsh
MON_TO_UNALIAS=$MON_DIR/.to_unalias
MON_TO_UNHASH=$MON_DIR/.to_unhash

MON_BIN=$MON_DIR/src/monkeypat.sh

# Aliases to the wrappers and appended PATH variables
# This is used to avoid clutter in the shell rc file
MON_RC_FILE=~/.monrc

SHELL_RC_FILES=()
if [[ -f ~/.bashrc ]]; then
    SHELL_RC_FILES+=(~/.bashrc)
fi
if [[ -f ~/.zshrc ]]; then
    SHELL_RC_FILES+=(~/.zshrc)
fi

MON_CONFIG_FILE=~/.monconfig

RED='\033[0;31m'
GREEN='\033[0;32m'
RESET_COLOR='\033[0m'

function _log() {
    if [ "$1" = '--error' ]; then
        shift
        echo -e "[${RED}ERROR${RESET_COLOR}] $@" 1>&2
    else
        echo -e "[${GREEN}OK${RESET_COLOR}] $@"
    fi
}
