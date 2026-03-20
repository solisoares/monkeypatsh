if typeset -f _mon_${cmd}_completion >/dev/null; then
    return
fi

# Save the original zsh completion function for the command
_mon_${cmd}_orig_completion=$_comps[${cmd}]

_mon_${cmd}_completion() {
    # Run original command's completion first
    service=${cmd}
    words[1]=${cmd}
    $_mon_${cmd}_orig_completion

    # Add monkeypatsh patches on top
    local patches=(${(f)"$(monkeypat.sh list ${cmd})"})

    _arguments -C \
        '1: :->patch' \
        '*:: :' && return

    case $state in
        patch)
            _describe 'patch' patches
            ;;
    esac
}

compdef _mon_${cmd}_completion ${cmd}