function _${cmd}_mon_completion() {
    local word1="${COMP_WORDS[1]}"
    local length="${#COMP_WORDS[@]}"
    # local cur="${COMP_WORDS[$COMP_CWORD]}"
    # local prev="${COMP_WORDS[$COMP_CWORD - 1]}"

    local patches="$(mon list ${cmd})"

	COMPREPLY=($(compgen -W "$patches" -- "$word1"))
	if [ "$length" -gt 2 ]; then
		COMPREPLY=()
	fi

}

complete -o nosort -F _${cmd}_mon_completion ${cmd}
