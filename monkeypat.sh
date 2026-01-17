#!/usr/bin/env bash

SOURCE_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))"
source $SOURCE_DIR/common.sh

_editor="editor"
if [ -n "$EDITOR" ]; then
    _editor="$(basename $EDITOR)"
fi
_config_editor="$(grep -oP '(?<=^editor = )\w*' $MON_CONFIG_FILE)"
if [ -e "$MON_CONFIG_FILE" ] && [ -n "$_config_editor" ]; then
    _editor="$_config_editor"
fi

function _() {
    # Handle multiple args for a given command
    # This allows registering multiple monkeypatsh
    # commands at once, i.e. `mon register <cmd>...`

    cmd="$1"

    shift
    if [ "$#" -eq 0 ]; then
        echo "mon: missing argument for '${cmd:1}'"
        echo "'${cmd:1}' requires at least 1 argument, you didn't provided one"
        return 1
    fi

    local arg
    for arg in "$@"; do
        "$cmd" "$arg"
    done

}

function _not_found_msg() {
    local cmd="$1"
    local not_found='command'
    if [[ "$cmd" == -* ]]; then
        not_found='option'
    fi
    echo "There is no registered $not_found named '$cmd'"
}

function _is_registered() {
    local cmd="$1"
    [ -f "$MON_REGISTERED/$cmd" ] && return 0 || return 1
}

function _is_registered_msg() {
    local cmd="$1"
    echo "Command '$cmd' is already registered"
}

function _register() {
    # Wrap command with monkeypatsh

    if [ "$#" -eq 0 ]; then
        echo "mon: missing argument for 'register'"
        echo "'register' requires at least 1 argument, you provided $#"
        return 1
    fi

    local cmd="$1"

    if [ "$cmd" = "mon" ]; then
        echo "error: monkeypatsh cannot be registered."
        return 1
    fi

    if [[ "$cmd" == -* || "$cmd" == *" "* ]]; then
        local cmd_cleaned="${cmd//-/}"
        cmd_cleaned="${cmd_cleaned// /}"

        echo "mon: cannot register a command like '$cmd'"
        echo "try \`mon register $cmd_cleaned \`"
        return 1
    fi

    if _is_registered "$cmd"; then
        _is_registered_msg "$cmd"
        return 1
    fi

    echo "alias $cmd=$MON_REGISTERED/$cmd" >>$MONRC_FILE
    touch "$MON_REGISTERED/$cmd"

    export cmd

    # Wrapper template
    local register_template="$MON_TEMPLATES/register_cmd.sh"
    if which "$cmd" >/dev/null; then
        register_template="$MON_TEMPLATES/register_existent_cmd.sh"
    fi

    cat "$register_template" | envsubst '${cmd}' >"$MON_REGISTERED/$cmd" &&
        chmod +x "$MON_REGISTERED/$cmd" &&
        echo "Registered command '$cmd'"

    # Completion template
    local completion_template="$MON_TEMPLATES/cmd_completion.sh"
    if ! which "$cmd" >/dev/null; then
        # add completion only for new commands for now
        cat "$completion_template" | envsubst '${cmd}' >"$MON_COMPLETIONS/$cmd"
    fi

}

function _open_file_at_line() {
    file="$1"
    line="$2"

    if [ "$_editor" = "editor" ]; then
        "$_editor" "$file" # well, tried
    fi

    case "$_editor" in
    *vim | *nano | emacs)
        "$_editor" +"$line" "$file"
        ;;
    code)
        echo "$file":"$line"
        "$_editor" --goto "$file":"$line"
        ;;
    kate)
        "$_editor" --line "$line" "$file"
        ;;
    subl)
        "$_editor" "$file":"$line"
        ;;
    esac

}

function _has_patch() {
    cmd="$1"
    sub="$2"
    if _list "$cmd" | grep -- "$sub" >/dev/null; then
        echo "mon: The patch '$sub' already exist"
        echo "Edit with 'mon edit $cmd $sub'"
        return 0
    fi
    return 1
}

function _patch() {
    # Patch an option or sub command (`opt`) to the registered command
    local cmd="$1"
    local opt="$2"
    local code="$3"

    if [ "$#" -lt 2 ]; then
        echo "mon: missing argument for 'patch'"
        echo "'patch' requires at least 2 arguments, you provided $#"
        return 1
    fi

    if ! _is_registered "$cmd"; then
        _not_found_msg "$cmd"
        return 1
    fi

    if _has_patch "$cmd" "$opt"; then return 1; fi

    export opt code

    # Add patch function
    cp "$MON_REGISTERED/$cmd" './tmpfile'
    patch_function_template="$MON_TEMPLATES/patch_cmd_function.sh"
    if [ -z "$code" ]; then
        patch_function_template="$MON_TEMPLATES/patch_cmd_function_stub.sh"
    fi
    patch_function="$(cat "$patch_function_template" | envsubst '${opt} ${code}')"
    awk -v r="$patch_function" '{gsub(/#!\/usr\/bin\/env bash/, r)}1' './tmpfile' >"$MON_REGISTERED/$cmd"

    # Add patch case
    patch_case="$(cat "$MON_TEMPLATES/patch_cmd_case.sh" | envsubst '${opt}')"
    cp "$MON_REGISTERED/$cmd" './tmpfile'
    awk -v r="$patch_case" '{gsub(/case "\$_opt" in/, r)}1' './tmpfile' >"$MON_REGISTERED/$cmd" &&
        rm './tmpfile'

    if [ -z "$code" ]; then
        line="$(sed -n '/# put your code here/{=;q;}' "$MON_REGISTERED/$cmd")"
        _open_file_at_line "$MON_REGISTERED/$cmd" "$line"
    fi

    echo "Patched: $cmd $opt"
}

function _confirmed() {
    local question="$1"

    local confirm
    read -p "$question" "${-+confirm}"
    confirm="${confirm:-n}"

    if [[ "${confirm,,}" =~ .*[n].* ]]; then
        # no: 1
        return 1
    else
        # yes: 0
        return 0
    fi
}

function _unregister() {
    local cmd="$1"

    if [[ $# -eq 1 ]] && [[ $1 = "-a" || $1 = "--all" ]]; then
        local cmds="$(mon list)"

        if _confirmed "Unregister all? (y/N): "; then
            _ _unregister $cmds
            return 0
        else
            echo "Aborting unregister..."
            return 1
        fi
    fi

    if ! _is_registered "$cmd"; then
        _not_found_msg "$cmd"
        return 1
    fi

    sed -i "/$cmd/d" $MONRC_FILE &&
        rm "$MON_REGISTERED/$cmd" &&
        rm "$MON_COMPLETIONS/$cmd" &&
        echo "Unregistered command '$cmd'"
}

function _check() {
    echo "============= .rc file ($MONRC_FILE) ============="
    echo -e "$(cat $MONRC_FILE)\n"

    echo "============= .config file ($MON_CONFIG_FILE) ============="
    echo -e "$(cat $MON_CONFIG_FILE)\n"

    echo "============= registered ($MON_REGISTERED) ============="
    echo -e "$(ls -l $MON_REGISTERED)\n"

    echo "============= completions ($MON_COMPLETIONS) ============="
    echo -e "$(ls -l $MON_COMPLETIONS)\n"
}

function _edit() {
    # Quick edit monkeypatsh itself
    if [ $# -eq 0 ] || [ $1 = 'mon' ]; then
        "$_editor" "$MON_DIR/monkeypat.sh"
        return 0
    fi

    # Quick edit .monrc and .monconfig
    if [ $1 = "-r" ] || [ $1 = "--rc" ]; then
        "$_editor" "$MONRC_FILE"
        return 0
    fi
    if [ $1 = "-c" ] || [ $1 = "--config" ]; then
        "$_editor" "$MON_CONFIG_FILE"
        return 0
    fi

    # Edit patch
    if [ "$#" -eq 2 ]; then
        local cmd="$1"
        local opt="$2"
        local opt_function="_$opt"
        if _has_patch "$cmd" "$opt" >/dev/null 2>&1; then
            local line=$(sed -n "/$opt_function/{=;q;}" "$MON_REGISTERED/$cmd")
            _open_file_at_line "$MON_REGISTERED/$cmd" "$line"
            return 0
        fi
    fi

    local paths=()
    local cmds="$@"
    local cmd

    for cmd in $cmds; do
        if _is_registered "$cmd" >/dev/null 2>&1; then
            paths+=("$MON_REGISTERED/$cmd")
        else
            _not_found_msg "$cmd"
        fi
    done

    if [ "${#paths[@]}" -eq 0 ]; then
        return 1
    fi

    "$_editor" "${paths[@]}"
    return 0
}

function _list() {
    local cmd="$1"
    if [ -z "$cmd" ]; then
        find "$MON_REGISTERED" -type f | xargs -I {} basename {} | sort
    else
        if [ "$cmd" = "-r" ] || [ "$cmd" = "--recursive" ]; then
            local cmds=$(_list)
            local _cmd
            for _cmd in $cmds; do
                echo "$_cmd:"
                _list "$_cmd" | xargs -I {} echo "  " {}
            done
        elif [ -f "$MON_REGISTERED/$cmd" ]; then
            cat "$MON_REGISTERED/$cmd" | grep -oP '(?<=function _).*(?=\()' | grep -v 'default'
        else
            _not_found_msg "$cmd"
        fi
    fi
}

function _uninstall() {
    bash "$MON_DIR/uninstall.sh"
}

function _backup() {
    local backup_file=~/.mon.bak.tar

    if [[ $# -eq 2 ]] && [[ "$1" = '-f' || "$1" = '--file' ]]; then
        backup_file="$2"
        if [ "${backup_file:0:1}" = '~' ]; then
            backup_file="${2/'~'/$HOME}" # replaces leading '~' for $HOME
        fi
    fi

    if [ -f "$backup_file" ]; then
        echo "There is already a backup at '$backup_file'"

        if ! _confirmed "Overwrite? (y/N): "; then
            echo "Aborting backup..."
            return 1
        fi
    fi

    local mon_rc="$(basename $MONRC_FILE)"
    local mon_config="$(basename $MON_CONFIG_FILE)"
    local mon_registered="$(basename $MON_DIR)/$(basename $MON_REGISTERED)"

    # Contents of the <backup> file:
    # 	.monrc
    # 	.monconfig
    # 	registered/
    # 		\_ <cmd_1>
    # 		\_ ...
    #   completions/
    #		\_ mon
    # 		\_ <cmd_1>
    # 		\_ ...
    tar -cf "$backup_file" -C ~ "$mon_rc" "$mon_config"
    tar -uf "$backup_file" -C "$MON_DIR" "$(basename $MON_REGISTERED)" >/dev/null 2>&1
    tar -uf "$backup_file" -C "$MON_DIR" "$(basename $MON_COMPLETIONS)" >/dev/null 2>&1

    echo "Backed up monkeypatsh."
    echo "To restore run: \`mon restore $backup_file\`"
}

function _restore() {
    if [ $# -eq 0 ]; then
        echo "mon: missing argument for 'restore'"
        echo "'restore' requires a backup file: \`mon restore <file.bak.tar>\`"
        return 1
    fi

    local backup_file="$1"

    local tmp_dir="$(mktemp -d)"
    local mon_rc_bak="$tmp_dir/$(basename $MONRC_FILE)"
    local mon_config_bak="$tmp_dir/$(basename $MON_CONFIG_FILE)"
    local mon_registered_bak="$tmp_dir/$(basename $MON_REGISTERED)"
    local mon_completions_bak="$tmp_dir/$(basename $MON_COMPLETIONS)"

    tar -xf "$backup_file" -C "$tmp_dir"

    cp "$mon_rc_bak" "$MONRC_FILE"
    cp "$mon_config_bak" "$MON_CONFIG_FILE"
    cp -r "$mon_registered_bak"/* "$MON_REGISTERED"
    cp -r "$mon_completions_bak"/* "$MON_COMPLETIONS"

    echo "Restored monkeypatsh configuration."
    echo "Refresh your session to use any restored commands."
}

function _help() {
    cat <<'EOF'
Commands available:
    register <cmd>...                    - Register commands to be wrapped with monkeypatsh.

    patch <cmd> <sub> [<code>]           - Patch a sub command or option to the registered command. There are 2 ways.
                                           1) You can add your code inline*:
                                              mon patch ls foo 'echo foo!!!'
                                              mon patch ls --bar 'echo bar!!!'
                                           2) You can summon your editor[1] and put your code there:
                                              mon patch ls foo
                                              mon patch ls --bar
                                           *) Keep your inline code simple. If you want to parse arguments or your
                                              code span multiple lines, use the second format.

    unregister <cmd>...                  - Unregister commands. Remove the wrapper and reset its behavior.

    check                                - [DEV] Quick sanity check.

    edit [<cmd>...]                      - Edit a registered command wrapper's or a patch with your preferred code editor[1].
         | [<cmd> <sub>]                   If you want to edit mon source code itself you can do `mon edit [mon]`.
         | [-c | --config]                 You can quick edit the .monconfig file with the option -c or --config.
         | [-r | --rc]                     And you can also quick edit the .monrc file, although not recommended,
                                           since it is automatically generated.

    list [<cmd>]                         - List all available monkeypatsh wrappers. If -r or --recursive is
         | [-r | --recursive]              used, list all wrappers and its patches. If <cmd> is used, list
                                           all the patches added for this command.

    uninstall                            - Uninstall monkeypatsh. Can also be run as `bash uninstall.sh` from
                                           the source dir.

    backup [-f | --file <backup>]        - Backup monkeypatsh into a restorable file.
	                                       If -f or --file is not provided, backups into ~/.mon.bak.tar

    restore <backup>                     - Restore monkeypatsh from file.

Options available:
    -h|--help                            - Show this help and exit. Can also be shown with just `mon`

Configuring monkeypatsh:
    You can configure how monkeypatsh behaves tweaking configs in the ~/.monconfig file.

    [1] Changing default code editor: `editor = <editor>`

EOF
}

function mon() {
    mon_cmd="$1"
    if [ -z "$mon_cmd" ]; then
        _help
        return
    fi

    shift
    case "$mon_cmd" in
    reg | regi | regis | regist | registe | register)
        _ _register "$@"
        ;;
    pat | patc | patch)
        _patch "$@"
        ;;
    unr | unre | unreg | unregi | unregis | unregist | unregiste | unregister)
        _ _unregister "$@" &&
            echo "You may restart your session to apply this."
        ;;
    che | chec | check)
        _check
        ;;
    edi | edit)
        _edit "$@"
        ;;
    lis | list)
        _list "$1"
        ;;
    uni | unin | unins | uninst | uninsta | uninstal | uninstall)
        _uninstall
        ;;
    bac | back | backu | backup)
        _backup "$@"
        ;;
    res | rest | resto | restor | restore)
        _restore "$@"
        ;;
    -h | --help)
        _help
        ;;
    *)
        echo "mon: unrecognized option '$mon_cmd'"
        echo "Try 'mon --help' for more information."
        ;;
    esac
}

mon "$@"
