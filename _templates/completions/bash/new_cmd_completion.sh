if [[ "$(type -t _mon_{{cmd}}_completion)" = 'function' ]]; then
    return
fi

function _mon_{{cmd}}_completion() {
    local cur="${COMP_WORDS[$COMP_CWORD]}"
    local length="${#COMP_WORDS[@]}"

    local patches="$(monkeypat.sh __list_cmd {{cmd}})"

	COMPREPLY=($(compgen -W "$patches" -- "$cur"))
	if [ "$length" -gt 2 ]; then
		COMPREPLY=()
	fi

}

complete -F _mon_{{cmd}}_completion {{cmd}}
