if declare -F _mon_${cmd}_completion >/dev/null; then
    return
fi

__mon_${cmd}_orig_completion="$(complete -p ${cmd} 2>/dev/null)"
__mon_${cmd}_orig_completion_no_func="$(echo "$__mon_${cmd}_orig_completion" | sed -r 's/complete\s+(.*?\s+)-F\s+.*/\1/' | sed 's/complete/compgen/')"
__mon_${cmd}_orig_completion_func="$(echo "$__mon_${cmd}_orig_completion" | sed -r 's/.*\s+-F\s+([a-zA-Z_]+)\s+[a-zA-Z_]+/\1/')"

function _mon_${cmd}_completion() {
    local cur="${COMP_WORDS[$COMP_CWORD]}"
    local length="${#COMP_WORDS[@]}"

    # Set COMPREPLY with original complete function
    __mon_${cmd}_orig_completion="$(complete -p ${cmd} 2>/dev/null)"
    __mon_${cmd}_orig_completion_no_func="$(echo "$__mon_${cmd}_orig_completion" | sed -r 's/complete\s+(.*?\s+)-F\s+.*/\1/' | sed 's/complete/compgen/')"
    ${__mon_${cmd}_orig_completion_func:-_minimal}

    # Update COMPREPLY with the patches
    if [ "$length" -eq 2 ]; then
        local patches="$(monkeypat.sh list ${cmd})"
        if [[ "$cur" =~ ^- ]]; then
            patches="$(echo "$patches" | sed '/^[^-]/d')" # show flags
        else
            patches="$(echo "$patches" | sed '/^-/d')" # show subcmds
        fi
        COMPREPLY+=($(compgen -W "$patches" -- "$cur"))
    fi

}

# Complete cmd with original compspec and with our completion
complete $__mon_${cmd}_orig_completion_no_func -F _mon_${cmd}_completion ${cmd}
