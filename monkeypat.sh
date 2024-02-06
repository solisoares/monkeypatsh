#!/usr/bin/bash

MON_DIR=~/.mon

MON_CONFIG_FILE=~/.monconfig

# monkeypatsh bin
function mon() {
    mon_cmd="$1"
    case "$mon_cmd" in
    register)
        # Register a user command to be wrapped with monkeypatsh
        cmd="$2"
        echo "alias $cmd=$MON_DIR/_$cmd" | sudo tee --append $MON_CONFIG_FILE >/dev/null
        echo "[MONKEYPATSH] Registered command '$cmd'"
        ;;
    patch)
        # Patch a sub command or option to the registered command
        original_cmd="$2"
        cmd=_"$2"
        sub="$3"
        code="$4"
        doc="$5"
        echo "\
#!/usr/bin/bash

function $cmd() {
    sub=\$1
    case \$sub in
        $sub)
           ${cmd}_$sub 
        ;;
        *)
           \\$original_cmd \$sub
        ;;
    esac
}

function ${cmd}_$sub() {
    $code
}

$cmd \"\$@\"
" | sudo tee --append $MON_DIR/$cmd >/dev/null
        sudo chmod +x $MON_DIR/$cmd
        echo "[MONKEYPATSH] patched: $original_cmd $sub"
        ;;
    unregister)
        original_cmd="$2"
        cmd=_"$2"
        sudo sed -i "/$original_cmd/d" $MON_CONFIG_FILE &&\
        sudo rm $MON_DIR/"$cmd" &&\
        echo "[MONKEYPATSH] Unregistered command '$original_cmd'. You may refresh your session to apply this"
        ;;
    -h | --help | *)
        echo -e "Commands available:\n\tregister\n\tpatch\n\tunregister\n"
        echo -e "Options available:\n\t-h|--help"
        ;;
    esac
}

mon "$@"
