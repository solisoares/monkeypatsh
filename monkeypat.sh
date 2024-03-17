#!/usr/bin/bash

MON_DIR=~/.mon

MON_CONFIG_FILE=~/.monconfig

function _() {
    # Handle multiple args for a given command
    # This allows registering multiple monkeypatsh
    # commands at once, i.e. `mon register <cmd>...`
    cmd="$1"

    shift
    if [ "$#" -eq 0 ]; then return; fi
    for arg in "$@"; do
        "$cmd" "$arg"
    done
}

function __register() {
    # Register a command to be wrapped with monkeypatsh
    original_cmd="$1"
    wrapper="${original_cmd}_"
    echo "alias $original_cmd=$MON_DIR/$wrapper" >>$MON_CONFIG_FILE &&
        touch "$MON_DIR/$wrapper" &&
        echo "[MONKEYPATSH] Registered command '$original_cmd'"
}

function __patch() {
    # Patch a sub command or option to the registered command
    original_cmd="$1"
    wrapper="${1}_"
    sub="$2"
    code="$3"
    echo "\
#!/usr/bin/bash

function $wrapper() {
    sub=\"\$@\"
    case \"\$sub\" in
        $sub)
           __$sub
        ;;
        *)
            if which \\$original_cmd >/dev/null 2>&1; then \\$original_cmd \"\$@\"; fi
        ;;
    esac
}

function __$sub() {
    $code
}

$wrapper \"\$@\"
" >>$MON_DIR/$wrapper &&
        sudo chmod +x $MON_DIR/$wrapper &&
        echo "[MONKEYPATSH] patched: $original_cmd $sub"
}

function __unregister() {
    original_cmd="$1"
    wrapper="$1"_
    sed -i "/$original_cmd/d" $MON_CONFIG_FILE &&
        rm $MON_DIR/"$wrapper" &&
        echo "[MONKEYPATSH] ✅ Unregistered command '$original_cmd'." &&
        echo "[MONKEYPATSH] 👉 You may refresh your session to apply this."
}

function __check() {
    cat <(echo '============= Mon config file (~/.monconfig) =============') \
        $MON_CONFIG_FILE <(echo -e '\n') \
        <(echo '================== Mon binary (~/.mon/) ==================') \
        <(ls -l $MON_DIR) \
        <(echo -e '\n')
}

function __edit() {
    original_cmd="$1"
    editor $MON_DIR/"${original_cmd}_"
}

function __list() {
    cmd="$1"
    if [ -z "$cmd" ]; then
        find $MON_DIR -type f ! -name 'mon' | xargs -I {} basename {} | cut -d '_' -f 1 | sort
    else
        if [ "$cmd" = "-r" ] || [ "$cmd" = "--recursive" ]; then
            cmds=$(__list)
            for cmd_ in $cmds; do
                echo "$cmd_:"
                __list "$cmd_" | xargs -I {} echo "  " {}
            done
        elif [ -f "$MON_DIR/${cmd}_" ]; then
            cat "$MON_DIR/${cmd}_" | grep -oP '(?<=function __).*(?=\()'
        else
            not_found='registered command'
            if [[ "$cmd" == -* ]]; then
                not_found='option'
            fi
            echo "There is no $not_found named '$cmd'"
        fi
    fi
}

function __help() {
    echo "\
Commands available:
    register <cmd>...                  - Register commands to be wrapped with monkeypatsh.
    patch <cmd> <sub> <code>           - Patch a sub command or option to the registered command.
    unregister <cmd>...                - Uregister commands. Remove the wrapper and reset its behavior.
    check                              - [DEV] Quick sanity check.
    edit <cmd>                         - Edit a registered command wrapper.
    list [-r | --recursive] | [<cmd>]  - List all available monkeypatsh wrappers. If -r or --recursive is
                                         used, list all wrappers and its patches. If <cmd> is used, list
                                         all the patches added for this command.

Options available:
    -h|--help                          - Show this help and exit
"
}

function mon() {
    mon_cmd="$1"
    shift
    case "$mon_cmd" in
    register)
        _ __register "$@"
        ;;
    patch)
        __patch "$@"
        ;;
    unregister)
        _ __unregister "$@"
        ;;
    check)
        __check
        ;;
    edit)
        __edit "$1"
        ;;
    list)
        __list "$1"
        ;;
    -h | --help)
        __help
        ;;
    *)
        if [ -z "$1" ]; then
            __help
        else
            echo "mon: unrecognized option '$1'"
            echo "Try 'mon --help' for more information."
        fi
        ;;
    esac
}

mon "$@"
