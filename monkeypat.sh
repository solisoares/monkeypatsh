#!/usr/bin/env bash

SOURCE_DIR="$(dirname ${BASH_SOURCE[0]})"
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
        echo "mon: missing argument for '${cmd:2}'"
        echo "'${cmd:2}' requires at least 1 argument, you didn't provided one"
        return 1
    fi

    for arg in "$@"; do
        "$cmd" "$arg"
    done

}

function _not_found_msg() {
    cmd="$1"
    not_found='command'
    if [[ "$cmd" == -* ]]; then
        not_found='option'
    fi
    echo "There is no registered $not_found named '$cmd'"
}

function _is_registered() {
    cmd="$1"
    if [ ! -f "$MON_REGISTERED/$cmd" ]; then
        _not_found_msg "$cmd"
        return 1
    fi
    return 0
}

function _register() {
    # Register a command to be wrapped with monkeypatsh
    if [ "$#" -eq 0 ]; then
        echo "mon: missing argument for 'register'"
        echo "'register' requires at least 1 argument, you provided $#"
        return 1
    fi

    local cmd="$1"
    if ! _is_registered "$cmd" >/dev/null 2>&1; then
        echo "alias $cmd=$MON_REGISTERED/$cmd" >>$MONRC_FILE &&
            touch "$MON_REGISTERED/$cmd"
    fi

    export cmd
    cat "$MON_TEMPLATES/register_cmd.sh" | envsubst '${cmd}' >"$MON_REGISTERED/$cmd" &&
        chmod +x "$MON_REGISTERED/$cmd" &&
        echo "Registered command '$cmd'"
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
    if mon list "$cmd" | grep "$sub" >/dev/null; then
        echo "mon: The patch '$sub' already exist"
        echo "Change it with 'mon edit $cmd $sub'"
        return 0
    fi
    return 1
}

function _patch() {
    # Patch a sub command or option to the registered command
    original_cmd="$1"
    wrapper="${1}_"
    sub="$2"
    code="$3"

    if [ "$#" -lt 2 ]; then
        echo "mon: missing argument for 'patch'"
        echo "'patch' requires at least 2 arguments, you provided $#"
        return 1
    fi

    if ! _is_registered "$wrapper"; then return 1; fi

    if _has_patch "$original_cmd" "$sub"; then return 1; fi

    export sub code

    # Add patch function
    cp $MON_DIR/$wrapper './tmpfile'
    patch_function_template="$MON_TEMPLATES/patch_cmd_function.sh"
    if [ -z "$code" ]; then
        patch_function_template="$MON_TEMPLATES/patch_cmd_function_stub.sh"
    fi
    patch_function="$(cat "$patch_function_template" | envsubst '${sub} ${code}')"
    awk -v r="$patch_function" '{gsub(/#!\/usr\/bin\/bash/, r)}1' './tmpfile' >$MON_DIR/$wrapper

    # Add patch case
    patch_case="$(cat "$MON_TEMPLATES/patch_cmd_case.sh" | envsubst '${sub}')"
    cp $MON_DIR/$wrapper './tmpfile'
    awk -v r="$patch_case" '{gsub(/case "\$sub_cmd" in/, r)}1' './tmpfile' >$MON_DIR/$wrapper &&
        rm './tmpfile'

    if [ -z "$code" ]; then
        line="$(sed -n '/# put your code here/{=;q;}' $MON_DIR/$wrapper)"
        _open_file_at_line "$MON_DIR/$wrapper" "$line"
    fi

    echo "[MONKEYPATSH] patched: $original_cmd $sub"
}

function _unregister() {
    local cmd="$1"

    if ! _is_registered "$cmd"; then return 1; fi

    sed -i "/$cmd/d" $MONRC_FILE &&
        rm  "$MON_REGISTERED/$cmd" &&
        echo "Unregistered command '$cmd'." &&
        echo "You may refresh your session to apply this."
}

function _check() {
    cat <(echo '============= Mon config file (~/.monrc) =============') \
        $MONRC_FILE <(echo -e '\n') \
        <(echo '================== Mon binary (~/.mon/) ==================') \
        <(ls -l $MON_DIR) \
        <(echo -e '\n')
}

function _edit() {
    if [ $# -eq 0 ]; then
        "$_editor" $MON_DIR/"mon_"
        return 0
    fi

    # Quick edit .monrc and .monconfig
    if [ $1 = "-r" ] || [ $1 = "--rc" ]; then
        "$_editor" "$MONRC_FILE"
        return
    fi
    if [ $1 = "-c" ] || [ $1 = "--config" ]; then
        "$_editor" "$MON_CONFIG_FILE"
        return
    fi

    # Edit patch
    if [ "$#" -eq 2 ]; then
        cmd="$1"
        wrapper="${cmd}_"
        sub="$2"
        sub_function="_$2"
        if _has_patch "$cmd" "$sub" >/dev/null 2>&1; then
            line=$(sed -n "/$sub_function/{=;q;}" "$MON_DIR/$wrapper")
            _open_file_at_line "$MON_DIR/$wrapper" "$line"
            return 0
        fi
    fi

    paths=()

    for original_cmd in "$@"; do
        if _is_registered "${original_cmd}_" >/dev/null 2>&1; then
            paths+=($MON_DIR/"${original_cmd}_")
        else
            _not_found_msg "$original_cmd"
        fi
    done

    if [ "${#paths[@]}" -eq 0 ]; then
        return 1
    fi

    "$_editor" "${paths[@]}"
    return 0
}

function _list() {
    cmd="$1"
    if [ -z "$cmd" ]; then
        find $MON_DIR -type f ! -name 'mon_' | xargs -I {} basename {} | cut -d '_' -f 1 | sort
    else
        if [ "$cmd" = "-r" ] || [ "$cmd" = "--recursive" ]; then
            cmds=$(_list)
            for cmd_ in $cmds; do
                echo "$cmd_:"
                _list "$cmd_" | xargs -I {} echo "  " {}
            done
        elif [ -f "$MON_DIR/${cmd}_" ]; then
            cat "$MON_DIR/${cmd}_" | grep -oP '(?<=function _).*(?=\()'
        else
            _not_found_msg "$cmd"
        fi
    fi
}

function _uninstall() {
    bash "$MON_DIR/uninstall.sh"
}

function _help() {
    echo "\
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
         | [<cmd> <sub>]                   If you want to edit mon source code itself you can do \`mon edit [mon]\`.
         | [-c | --config]                 You can quick edit the .monconfig file with the option -c or --config.
         | [-r | --rc]                     And you can also quick edit the .monrc file, although not recommended,
                                           since it is automatically generated.

    list [<cmd>]                         - List all available monkeypatsh wrappers. If -r or --recursive is
         | [-r | --recursive]              used, list all wrappers and its patches. If <cmd> is used, list
                                           all the patches added for this command.

    uninstall                            - Uninstall monkeypatsh. Can also be run as \`bash uninstall.sh\` from
                                           the source dir.

Options available:
    -h|--help                            - Show this help and exit. Can also be shown with just \`mon\`

Configuring MonkeyPatsh:
    You can configure how MonkeyPatsh behaves tweaking configs in the ~/.monconfig file.

    [1] Changing default code editor: \`editor = <editor>\`
"
}

function mon() {
    mon_cmd="$1"
    if [ -z "$mon_cmd" ]; then
        _help | less
        return
    fi

    shift
    case "$mon_cmd" in
    r | re | reg | regi | regis | regist | registe | register)
        _ _register "$@"
        ;;
    p | pa | pat | patc | patch)
        _patch "$@"
        ;;
    u | un | unr | unre | unreg | unregi | unregis | unregist | unregiste | unregister)
        _ _unregister "$@"
        ;;
    c | ch | che | chec | check)
        _check
        ;;
    e | ed | edi | edit)
        _edit "$@"
        ;;
    l | li | lis | list)
        _list "$1"
        ;;
    uninstall)
        _uninstall
        ;;
    -h | --help)
        _help | less
        ;;
    *)
        echo "mon: unrecognized option '$mon_cmd'"
        echo "Try 'mon --help' for more information."
        ;;
    esac
}

mon "$@"
