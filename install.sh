source ./constants.sh

function add_config_file() {
	# Create monkeypatsh config file
	touch $MON_CONFIG_FILE
	echo "[MONKEYPATSH] Created $MON_CONFIG_FILE file"
}

function add_bin() {
	# Add local executable
	mkdir -p $MON_DIR
	# TODO: copy instead of symlinking on code release
	ln --symbolic $(readlink -e "$MON_SOURCE") $MON_BIN
	chmod +x $MON_BIN
	echo "[MONKEYPATSH] Added monkeypatsh binary to $MON_BIN"
}

function setup_config_file() {
	# Update PATH to listen at monkeypatsh bin directory first
	if ! grep "PATH=$MON_DIR:\$PATH" $MON_CONFIG_FILE >$DEVNULL; then
		echo "PATH=$MON_DIR:\$PATH" >>$MON_CONFIG_FILE
	fi
	echo "[MONKEYPATSH] Updated PATH to look first at $MON_DIR"

	# Add monkeypatsh completions
	echo "complete -W 'register patch unregister check edit list -h --help' mon" >>$MON_CONFIG_FILE

	# Allow original completion for existing commands
	echo "setopt complete_aliases" >>$MON_CONFIG_FILE
}

function setup_rc_file() {
	# Since the the aliases definition and PATH variables are in the monkeypatsh config file
	# and not in the .rc config file, always source it on start up
	echo source $MON_CONFIG_FILE >>$SHRC_FILE

	# Monkeypatsh is itself an alias.
	# Each call to `mon` sources the monkeypatsh config file to make commands
	# aliases up to date on each monkeypatsh registration.
	echo "alias mon='source $MON_CONFIG_FILE > $DEVNULL && $MON_BIN'" >>$SHRC_FILE

	echo "[MONKEYPATSH] Configured $SHRC_FILE file"
}

add_config_file &&
	add_bin &&
	setup_config_file &&
	setup_rc_file &&
	echo "[MONKEYPATSH] ✅ monkeypatsh has been installed successfully." &&
	echo "[MONKEYPATSH] 👉 Refresh your session and run 'mon --help'" ||
	echo "[MONKEYPATSH] ❌ Failed to install monkeypatch"
