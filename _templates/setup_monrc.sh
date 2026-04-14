# This file is sourced from your shell .rc file.
# It setups completions and appropriate PATHs on the first source. And refreshes
# commands automatically on the go.

function __mon_source_completions() {
    local cmd="${1:-*}" # specific command or all (including mon)

    if [[ -d "{{MON_COMPLETIONS_BASH}}" && -n $BASH ]]; then
        local file
        while read -r file; do
            if [[ -f "$file" ]]; then
                source "$file"
            fi
        done <<<"$(find "{{MON_COMPLETIONS_BASH}}" -type f -name "$cmd")"
    fi
    if [[ -d "{{MON_COMPLETIONS_ZSH}}" && -n $ZSH_NAME ]]; then
        local file
        while read -r file; do
            if [[ -f "$file" ]]; then
                source "$file"
            fi
        done <<<"$(find "{{MON_COMPLETIONS_ZSH}}" -type f -name "$cmd")"
    fi
}

if ! type _mon_completion >/dev/null 2>&1; then
    # Source all completions
    __mon_source_completions
fi

if ! echo "$PATH" | grep -qE '\.mon\/'; then
    # Export monkeypat.sh
    export PATH="{{MON_DIR}}/src/:$PATH"

    # Export registered binary commands
    export PATH="{{MON_REGISTERED_BIN}}:$PATH"
fi

function __mon_alias() {
    # Monkeypatsh is itself an alias that calls the real monkeypat.sh and after
    # the execution keeps the session up to date so no refresh is needed. I tried
    # to keep this alias minimal because it must be portable across shells.

    # Main execution
    "{{MON_BIN}}" "$@"
    local exit="$?"
    if [[ "$exit" -ne 0 ]]; then
        return "$exit"
    fi

    # Keep session up to date
    local mon_cmd="$1"
    case "$mon_cmd" in
    reg | regi | regis | regist | registe | register | \
        res | rest | resto | restor | restore)
        # Refresh aliases
        source "{{MON_RC_FILE}}"

        # Refresh completions
        if [[ "$mon_cmd" =~ reg.* ]]; then
            local cmd
            while read -r cmd; do
                __mon_source_completions "$cmd"
            done <<<"$(cat "{{MON_TO_REFRESH_COMPLETION}}")"
            rm "{{MON_TO_REFRESH_COMPLETION}}"
        else
            __mon_source_completions
        fi
        ;;
    unr | unre | unreg | unregi | unregis | unregist | unregiste | unregister)
        # Unset aliases and binaries
        if [[ -f "{{MON_TO_UNALIAS}}" ]]; then
            unalias $(cat "{{MON_TO_UNALIAS}}") >/dev/null 2>&1 && rm "{{MON_TO_UNALIAS}}"
        fi
        if [[ -f "{{MON_TO_UNHASH}}" ]]; then
            hash -d $(cat "{{MON_TO_UNHASH}}") >/dev/null 2>&1 && rm "{{MON_TO_UNHASH}}"
        fi
        ;;
    esac
}

alias mon='__mon_alias'

# --- REGISTERED ALIASES ---
