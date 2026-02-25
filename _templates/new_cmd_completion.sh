function _mon_${cmd}_completion() {
    local cur="${COMP_WORDS[$COMP_CWORD]}"
    local length="${#COMP_WORDS[@]}"

    local patches="$(mon list ${cmd})"

	COMPREPLY=($(compgen -W "$patches" -- "$cur"))
	if [ "$length" -gt 2 ]; then
		COMPREPLY=()
	fi

}

complete -o nosort -F _mon_${cmd}_completion ${cmd}
