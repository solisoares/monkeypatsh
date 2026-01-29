case "$_opt" in
    "$(__clean_opt ${opt})")
        shift
        _${opt} "$@"
    ;;
