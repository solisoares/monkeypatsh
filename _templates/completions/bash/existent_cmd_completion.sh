# Save the original bash completion function and options for the command
__mon_{{cmd}}_orig_completion="$(complete -p {{cmd}} 2>/dev/null)"
__mon_{{cmd}}_orig_completion_no_func="$(echo "$__mon_{{cmd}}_orig_completion" | sed -E 's/complete(.*)[[:space:]]+-F.*/\1/')"
__mon_{{cmd}}_orig_completion_func="$(echo "$__mon_{{cmd}}_orig_completion" | sed -E 's/.*[[:space:]]+-F[[:space:]]+([a-zA-Z_]+)[[:space:]]+[a-zA-Z_]+/\1/')"

function _mon_{{cmd}}_completion() {
    local cur="${COMP_WORDS[$COMP_CWORD]}"
    local length="${#COMP_WORDS[@]}"

    # Set COMPREPLY with original complete function
    if [[ -n "$__mon_{{cmd}}_orig_completion_func" ]]; then
        "$__mon_{{cmd}}_orig_completion_func" "$@"
    fi

    # Update COMPREPLY with the patches
    if [ "$length" -eq 2 ]; then
        local patches="$(monkeypat.sh __list_cmd {{cmd}})"
        if [[ "$cur" =~ ^- ]]; then
            patches="$(echo "$patches" | sed '/^[^-]/d')" # show flags
        else
            patches="$(echo "$patches" | sed '/^-/d')" # show subcmds
        fi
        COMPREPLY+=($(compgen -W "$patches" -- "$cur"))
    fi

}

# Complete cmd with original compspec and with our completion
complete $__mon_{{cmd}}_orig_completion_no_func -F _mon_{{cmd}}_completion {{cmd}}
