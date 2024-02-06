source ./constants.sh

# Remove monkeypatsh executable and wrappers
sudo rm -rf $MON_DIR
echo "[MONKEYPATSH] Removed monkeypatsh binaries from $MON_DIR"

# Remove .monconfig file
sudo rm $MON_CONFIG_FILE
echo "[MONKEYPATSH] Removed $MON_CONFIG_FILE"

# Remove configs from .rc file 
sudo sed -i '/monconfig/d' $SHRC_FILE
echo "[MONKEYPATSH] Removed configs from $SHRC_FILE"

echo "[MONKEYPATSH] All done. monkeypatsh has been uninstalled"