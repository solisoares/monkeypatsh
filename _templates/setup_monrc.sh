if [[ -z "$MON_SETUP" ]]; then
    export MON_SETUP=1

    # Export monkeypat.sh and registered binary commands
    export PATH="{{MON_DIR}}/src/:$PATH"
    export PATH="{{MON_REGISTERED_BIN}}:$PATH"

    # Source mon completions
    if [[ -d "{{MON_COMPLETIONS_BASH}}" && -n $BASH ]]; then
        source "{{MON_COMPLETIONS_BASH}}/mon"
    fi
    if [[ -d "{{MON_COMPLETIONS_ZSH}}" && -n $ZSH_NAME ]]; then
        source "{{MON_COMPLETIONS_ZSH}}/mon"
    fi
fi

function __mon_alias() {
    # Main execution
    "{{MON_BIN}}" "$@"
    local exit="$?"
    if [[ "$exit" -ne 0 ]]; then
        return "$exit"
    fi

    local cmd="$1"
    case "$cmd" in
    reg | regi | regis | regist | registe | register | \
        res | rest | resto | restor | restore)
        # Refresh aliases
        source "{{MON_RC_FILE}}"

        # Refresh completions
        if [[ -d "{{MON_COMPLETIONS_BASH}}" && -n $BASH ]]; then
            local registered_completions
            read -d '\n' -a registered_completions <<<"$(find "{{MON_COMPLETIONS_BASH}}" -type f ! -name 'mon')"
            for file in "${registered_completions[@]}"; do source "$file"; done
        fi
        if [[ -d "{{MON_COMPLETIONS_ZSH}}" && -n $ZSH_NAME ]]; then
            local registered_completions
            read -d '\n' -a registered_completions <<<"$(find "{{MON_COMPLETIONS_ZSH}}" -type f ! -name 'mon')"
            for file in "${registered_completions[@]}"; do source "$file"; done
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

# Monkeypatsh is itself an alias
alias mon='__mon_alias'

# --- REGISTERED ALIASES ---
