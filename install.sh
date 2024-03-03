source ./constants.sh

# Add monkeypatsh config file
touch $MON_CONFIG_FILE

# Add local executable
sudo mkdir -p $MON_DIR
sudo ln --symbolic `readlink -e "$MON_SOURCE"` $MON_BIN
sudo chmod +x $MON_BIN
echo "[LOG] Added monkeypatsh binary to $MON_BIN"

# Update PATH to listen at monkeypatsh bin directory first
if ! grep "PATH=$MON_DIR:\$PATH" $MON_CONFIG_FILE > $DEVNULL 
then echo "PATH=$MON_DIR:\$PATH" >> $MON_CONFIG_FILE
fi
echo "[LOG] Updated PATH to look first at $MON_DIR"

# Update MANPATH to listen at local manpath first
if ! grep "MANPATH=$LOCAL_MANPATH:\$MANPATH" $MON_CONFIG_FILE > $DEVNULL 
then echo "MANPATH=$LOCAL_MANPATH:\$MANPATH" >> $MON_CONFIG_FILE
fi
echo "[LOG] Updated MANPATH to look first at $LOCAL_MANPATH"

# Since the the aliases definition and PATH variables are in the monkeypatsh config file
# and not in the .rc config file, always source it on start up 
echo source $MON_CONFIG_FILE >> $SHRC_FILE

# Monkeypatsh is itself an alias.
# Each call to `mon` sources the monkeypatsh config file to make commands
# aliases up to date on each monkeypatsh registration.
echo "alias mon='source $MON_CONFIG_FILE > $DEVNULL && $MON_BIN'" >> $SHRC_FILE

echo "[LOG] monkeypatsh has been installed successfully"