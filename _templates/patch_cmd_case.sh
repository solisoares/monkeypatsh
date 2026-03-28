case "$opt" in
    "$(_clean_opt {{opt}})")
        shift
        _mon_{{opt}} "$@"
    ;;
