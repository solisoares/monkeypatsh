source ./constants.sh

function rm_mondir() {
    # Remove monkeypatsh executable and wrappers
    rm -rf $MON_DIR
    echo "[MONKEYPATSH] Removed monkeypatsh binary and wrappers from $MON_DIR and this directory itself"
}

function rm_config_file() {
    # Remove .monconfig file
    rm $MON_CONFIG_FILE
    echo "[MONKEYPATSH] Removed $MON_CONFIG_FILE"
}

function update_rc_file() {
    # Remove setup configs from .rc file
    sed -i '/monconfig/d' $SHRC_FILE
    echo "[MONKEYPATSH] Removed setup configs from $SHRC_FILE"
}

rm_mondir &&
    rm_config_file &&
    update_rc_file &&
    echo "[MONKEYPATSH] ✅ All done. monkeypatsh has been uninstalled." ||
    echo "[MONKEYPATSH] ❌ Failed to uninstall monkeypatch"

