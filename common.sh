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
MON_TO_REFRESH_COMPLETION=$MON_DIR/.to_refresh_completion

MON_VERSION="1.0.0"

if [[ "$MON_TESTING" -eq 1 ]]; then
    MON_TO_UNALIAS=/dev/null
    MON_TO_UNHASH=/dev/null
    MON_TO_REFRESH_COMPLETION=/dev/null
fi

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

function _error() {
    local source="$1"

    shift
    local message="$@"

    if [[ -n "$source" ]]; then
        echo "mon: $source: $message" >&2
    else
        echo "mon: $message" >&2
    fi

}

function _error_hint() {
    echo "  $@" >&2
}

function _info() {
    echo "$@"
}

function _render() {
    # envsubst wannabe: renders a template replacing '<value_x>' by '{{<name_x>}}'
    #   _render <template> \
    #       <name1> <name2> <name3> ... \
    #       <value1> <value2> <value3> ...

    local file="$1"
    shift

    local var_data=("$@")
    local len="$#"
    if [[ $((len % 2)) -ne 0 ]]; then
        _error "render" 'template rendering has failed'
        exit 1
    fi

    local half_len=$((len / 2))
    local var_names=("${var_data[@]:0:$half_len}")
    local var_values=("${var_data[@]:$half_len:$half_len}")

    local file_content="$(<"$file")"
    local i
    for i in "${!var_names[@]}"; do
        name="${var_names[$i]}"
        value="${var_values[$i]}"
        file_content="${file_content//\{\{${name}\}\}/${value}}"
    done

    echo "$file_content"

}

function _log() {
    if [ "$1" = '--error' ]; then
        shift
        echo -e "[${RED}ERROR${RESET_COLOR}] $@" 1>&2
    else
        echo -e "[${GREEN}OK${RESET_COLOR}] $@"
    fi
}
