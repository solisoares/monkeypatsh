source ./constants.sh

function add_monrc_file() {
	# Create monkeypatsh rc file
	touch $MONRC_FILE
	echo "[MONKEYPATSH] Created $MONRC_FILE file"
}

function add_empty_monconfig_file() {
	echo "# Add your configs here" >>"$MON_CONFIG_FILE"
	echo "# Lines starting with '#' are comments" >>"$MON_CONFIG_FILE"
	echo "# editor = vim" >>"$MON_CONFIG_FILE"
	echo "[MONKEYPATSH] Created empty "$MON_CONFIG_FILE" file"
}

function copy_mon_bin() {
	# TODO: copy instead of symlinking on code release
	# Add local executable
	mkdir -p $MON_DIR
	ln --symbolic $(readlink -e "$MON_SOURCE") $MON_BIN
	chmod +x $MON_BIN
	echo "[MONKEYPATSH] Added monkeypatsh binary to $MON_BIN"
}

function copy_scripts() {
	# TODO: copy instead of symlinking on code release
	mkdir -p $MON_SCRIPTS
	ln --symbolic $(readlink -e "$MON_SOURCE_CONSTANTS") $MON_SCRIPTS/constants.sh
	ln --symbolic $(readlink -e "$MON_SOURCE_UNINSTALL") $MON_SCRIPTS/uninstall.sh
	echo "[MONKEYPATSH] Copied scripts to $MON_DIR/.scripts"
}

function setup_monrc_file() {
	# Update PATH to listen at monkeypatsh bin directory first
	if ! grep "PATH=$MON_DIR:\$PATH" $MONRC_FILE >$DEVNULL; then
		echo "PATH=$MON_DIR:\$PATH" >>$MONRC_FILE
	fi
	echo "[MONKEYPATSH] Updated PATH to look first at $MON_DIR"

	# Add monkeypatsh completions
	echo "complete -W 'register patch unregister check edit list -h --help' mon" >>$MONRC_FILE

	# Allow original completion for existing commands
	echo "setopt complete_aliases" >>$MONRC_FILE
}

function setup_shellrc_file() {
	# Since the the aliases definition and PATH variables are in the monkeypatsh rc file
	# and not in the shell rc file, always source it on start up
	echo source $MONRC_FILE >>$SHRC_FILE

	# Monkeypatsh is itself an alias.
	# Each call to `mon` sources the monkeypatsh rc file to make commands
	# aliases up to date on each monkeypatsh registration.
	echo "alias mon='source $MONRC_FILE > $DEVNULL && $MON_BIN'" >>$SHRC_FILE

	echo "[MONKEYPATSH] Configured $SHRC_FILE file"
}

add_monrc_file &&
	copy_mon_bin &&
	add_empty_monconfig_file &&
	copy_scripts &&
	setup_monrc_file &&
	setup_shellrc_file &&
	echo "[MONKEYPATSH] ✅ monkeypatsh has been installed successfully." &&
	echo "[MONKEYPATSH] 👉 Refresh your session and run 'mon --help'" ||
	echo "[MONKEYPATSH] ❌ Failed to install monkeypatch"
