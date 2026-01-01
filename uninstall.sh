#!/usr/bin/env bash

set -eE
trap "_log --error 'Failed to uninstall monkeypatch'" ERR

# source ~/.mon/.scripts/common.sh
source ./common.sh

function rm_mondir() {
    # Remove monkeypatsh executable and wrappers
    rm -r $MON_DIR
    _log "Removed monkeypatsh binary and wrappers from $MON_DIR and this directory itself as well as scripts"
}

function rm_monrc_file() {
    rm $MONRC_FILE
    _log "Removed $MONRC_FILE"
}

function rm_monconfig_file() {
    if [ -f $MON_CONFIG_FILE ]; then
        rm $MON_CONFIG_FILE
        _log "Removed $MON_CONFIG_FILE"
    fi
}

function update_shellrc_file() {
    # Remove setup configs from .rc file
    sed -i '/monrc/d' $SHRC_FILE
    _log "Removed setup configs from $SHRC_FILE"
}

rm_mondir
rm_monrc_file
rm_monconfig_file
update_shellrc_file
echo "All done. Monkeypatsh has been uninstalled"
