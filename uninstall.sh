source ~/.mon/.scripts/constants.sh

function rm_mondir() {
    # Remove monkeypatsh executable and wrappers
    rm -rf $MON_DIR
    echo "[MONKEYPATSH] Removed monkeypatsh binary and wrappers from $MON_DIR and this directory itself as well as scripts"
}

function rm_monrc_file() {
    rm $MONRC_FILE
    echo "[MONKEYPATSH] Removed $MONRC_FILE"
}

function rm_monconfig_file() {
    if [ -f $MON_CONFIG_FILE ]; then
        rm $MON_CONFIG_FILE
        echo "[MONKEYPATSH] Removed $MON_CONFIG_FILE"
    fi
}

function update_shellrc_file() {
    # Remove setup configs from .rc file
    sed -i '/monrc/d' $SHRC_FILE
    echo "[MONKEYPATSH] Removed setup configs from $SHRC_FILE"
}

rm_mondir &&
    rm_monrc_file &&
    rm_monconfig_file &&
    update_shellrc_file &&
    echo "[MONKEYPATSH] ✅ All done. monkeypatsh has been uninstalled." ||
    echo "[MONKEYPATSH] ❌ Failed to uninstall monkeypatch"
