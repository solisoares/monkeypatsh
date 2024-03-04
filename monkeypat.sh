#!/usr/bin/bash

MON_DIR=~/.mon

MON_CONFIG_FILE=~/.monconfig

function __register() {
    # Register a command to be wrapped with monkeypatsh
    cmd="$1"
    echo "alias $cmd=$MON_DIR/${cmd}_" >>$MON_CONFIG_FILE &&
        touch "$MON_DIR/${cmd}_" &&
        echo "[MONKEYPATSH] Registered command '$cmd'"
}

function __patch() {
    # Patch a sub command or option to the registered command
    original_cmd="$1"
    cmd="${1}_"
    sub="$2"
    code="$3"
    echo "\
#!/usr/bin/bash

function $cmd() {
    sub=\"\$@\"
    case \"\$sub\" in
        $sub)
           _$sub
        ;;
        *)
           \\$original_cmd \"\$@\"
        ;;
    esac
}

function _$sub() {
    $code
}

$cmd \"\$@\"
" >>$MON_DIR/$cmd &&
        sudo chmod +x $MON_DIR/$cmd &&
        echo "[MONKEYPATSH] patched: $original_cmd $sub"
}

function __unregister() {
    original_cmd="$1"
    cmd="$2"_
    sudo sed -i "/$original_cmd/d" $MON_CONFIG_FILE &&
        sudo rm $MON_DIR/"$cmd" &&
        echo "[MONKEYPATSH] ✅ Unregistered command '$original_cmd'."
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
    find $MON_DIR -type f ! -name 'mon' | xargs -I {} basename {} | cut -d '_' -f 1 | sort
}

function __help() {
    echo "\
Commands available:
    register
    patch
    unregister
    check
    edit
    list

Options available:
    -h|--help
"
}

function mon() {
    mon_cmd="$1"
    case "$mon_cmd" in
    register)
        shift
        __register "$1"
        ;;
    patch)
        shift
        __patch "$@"
        ;;
    unregister)
        shift
        __unregister "$1"
        ;;
    check)
        __check
        ;;
    edit)
        shift
        __edit "$1"
        ;;
    list)
        __list
        ;;
    -h | --help | *)
        __help
        ;;
    esac
}

mon "$@"
