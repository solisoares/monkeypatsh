if typeset -f _mon_{{cmd}}_completion > /dev/null; then
    return
fi

_mon_{{cmd}}_completion() {
    local patches=(${(f)"$(monkeypat.sh list {{cmd}})"})

    _arguments -C \
        '1: :->patch' \
        '*: :' && return

    case $state in
        patch)
            _describe 'patch' patches
            ;;
    esac
}

compdef _mon_{{cmd}}_completion {{cmd}}