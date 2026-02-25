#!/usr/bin/env bash

SOURCE_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))"
source $SOURCE_DIR/common.sh

alias_title="$(
    cat <<EOF
╭───────╮
│ Alias │
├───────╯
EOF
)"

bin_title="$(
    cat <<EOF
╭───────╮
│  Bin  │
├───────╯
EOF
)"

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
    [[ -f "$MON_REGISTERED_ALIAS/$cmd" || -f "$MON_REGISTERED_BIN/$cmd" ]] && return 0 || return 1
}

function _is_alias() {
    local cmd="$1"
    [[ -f "$MON_REGISTERED_ALIAS/$cmd" ]] && return 0 || return 1
}

function _is_bin() {
    local cmd="$1"
    [[ -f "$MON_REGISTERED_BIN/$cmd" ]] && return 0 || return 1
}

function _registered_dir {
    local cmd="$1"

    if ! _is_registered "$cmd"; then
        _not_found_msg "$cmd"
        return 1
    fi

    if _is_alias "$cmd"; then
        printf "$MON_REGISTERED_ALIAS"
    else
        printf "$MON_REGISTERED_BIN"
    fi

    return 0
}

function _is_registered_msg() {
    local cmd="$1"

    local location="$(_registered_dir $cmd)"

    if [ "$location" = "$MON_REGISTERED_ALIAS" ]; then
        echo "'$cmd' already registered as alias"
    else
        echo "'$cmd' already registered as bin"
    fi

}

function _register() {
    # Wrap command with monkeypatsh

    if [ "$#" -eq 0 ]; then
        echo "mon: missing argument for 'register'"
        echo "'register' requires at least 1 argument, you provided $#"
        return 1
    fi

    local location
    case "$1" in
    --bin)
        location="$MON_REGISTERED_BIN"
        shift
        ;;
    --alias)
        location="$MON_REGISTERED_ALIAS"
        shift
        ;;
    *)
        location="$MON_REGISTERED_ALIAS"
        ;;
    esac

    local cmds=("$@")

    local cmd
    for cmd in "${cmds[@]}"; do
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

        local old_location
        local changed_location=0

        if _is_registered "$cmd"; then
            old_location="$(_registered_dir $cmd)"
            if [ "$location" = "$old_location" ]; then
                _is_registered_msg "$cmd"
                continue
            else
                changed_location=1
            fi
        fi

        if [ "$changed_location" -eq 1 ]; then
            local change_type
            if [ "$location" = "$MON_REGISTERED_ALIAS" ]; then
                change_type="alias"
            else
                change_type="bin"
            fi

            _is_registered_msg $cmd
            if ! _has_confirmed "Change to $change_type?"; then
                echo "Aborting change..."
                continue
            fi

            mv "$old_location/$cmd" "$location/$cmd"

            if [ "$location" = "$MON_REGISTERED_BIN" ]; then
                _unalias "$cmd"
            fi

            echo "'$cmd' updated to $change_type."
        fi

        if [[ "$location" = "$MON_REGISTERED_ALIAS" ]]; then
            echo "alias $cmd=$MON_REGISTERED_ALIAS/$cmd" >>$MON_RC_FILE
        fi

        if [ "$changed_location" -eq 1 ]; then
            continue
        fi

        local completion_template
        local register_template

        if which "$cmd" >/dev/null; then
            register_template="$MON_TEMPLATES/register_existent_cmd.sh"
            completion_template="$MON_TEMPLATES/existent_cmd_completion.sh"
        else
            register_template="$MON_TEMPLATES/register_new_cmd.sh"
            completion_template="$MON_TEMPLATES/new_cmd_completion.sh"
        fi

        export cmd
        # Render registered template
        cat "$register_template" | envsubst '${cmd}' >"$location/$cmd"
        chmod +x "$location/$cmd"
        # Render completion template
        cat "$completion_template" | envsubst '${cmd}' >"$MON_COMPLETIONS/$cmd"

        echo "Registered command '$cmd'"
    done

    echo "Refresh commands with \`mon refresh\`"

}

function _open_file() {
    local file="$1"
    local pattern="$2"

    local config_editor
    if [[ -f "$MON_CONFIG_FILE" ]]; then
        config_editor="$(cat $MON_CONFIG_FILE | sed -nE '/^\s*#/! s/\s*editor\s*=\s*(\w+)\s*.*/\1/p')"
        if [[ -n "$config_editor" ]] && ! command -v "$config_editor" >/dev/null; then
            echo "error: config: '$config_editor' not found"
            return 1
        fi
    fi

    if [[ -z "$config_editor" ]] && [[ -n "$EDITOR" ]] && ! command -v "$EDITOR" >/dev/null; then
        echo "error: EDITOR: '$EDITOR' not found"
        return 1
    fi

    local editor="${config_editor:-${EDITOR:-vi}}"

    if [[ -z "$pattern" ]]; then
        if [[ -d "$file" ]]; then
            (cd "$file" && "$editor" "$file")
        else
            "$editor" "$file"
        fi
        return
    fi

    function __get_pattern_line() {
        local pattern="$1"
        local file="$2"
        local line="$(sed -n "/$pattern/{=;q;}" "$file")"
        echo "$line"
    }

    local line="$(__get_pattern_line "$pattern" $location/$cmd)"

    if [[ -z "$line" ]]; then
        "$editor" "$file"
        return
    fi

    if [ "$editor" = "editor" ]; then
        "$editor" "$file" # well, tried
        return
    fi

    case "$editor" in
    vi | *vim | *nano | emacs)
        "$editor" +"$line" "$file"
        ;;
    code)
        "$editor" --goto "$file":"$line"
        ;;
    kate)
        "$editor" --line "$line" "$file"
        ;;
    subl)
        "$editor" "$file":"$line"
        ;;
    esac

}

function _has_patch() {
    local cmd="$1"
    local sub="$2"
    if _list "$cmd" | grep -- "$sub" >/dev/null; then
        return 0
    fi
    return 1
}

function _has_patch_msg() {
    local cmd="$1"
    local patch="$2"
    echo "error: '$cmd $patch' already exist"
}

function _dont_has_patch_msg() {
    local cmd="$1"
    local patch="$2"
    echo "error: '$cmd $patch' does not exist"
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

    if _has_patch "$cmd" "$opt"; then
        _has_patch_msg "$cmd" "$opt"
        return 1
    fi

    local location="$(_registered_dir $cmd)"

    export opt code

    # Add patch function
    cp "$location/$cmd" './tmpfile'
    local patch_function_template="$MON_TEMPLATES/patch_cmd_function.sh"
    if [ -z "$code" ]; then
        patch_function_template="$MON_TEMPLATES/patch_new_cmd_function_empty.sh"
        if which "$cmd" >/dev/null; then
            patch_function_template="$MON_TEMPLATES/patch_existent_cmd_function_empty.sh"
        fi
    fi
    local patch_function="$(cat "$patch_function_template" | envsubst '${opt} ${code}')"
    awk -v r="$patch_function" '{gsub(/#!\/usr\/bin\/env bash/, r)}1' './tmpfile' >"$location/$cmd"

    # Add patch case
    local patch_case="$(cat "$MON_TEMPLATES/patch_cmd_case.sh" | envsubst '${opt}')"
    cp "$location/$cmd" './tmpfile'
    awk -v r="$patch_case" '{gsub(/case "\$_opt" in/, r)}1' './tmpfile' >"$location/$cmd" &&
        rm './tmpfile'

    if [ -z "$code" ]; then
        local patch="_mon_$opt"
        _open_file "$location/$cmd" "$patch"
    fi

    echo "Patched: $cmd $opt"
}

function _has_confirmed() {
    local question="$1"
    local default="${2:-y}"

    local options='(y/N)'
    if [[ "${default,,}" = 'y' ]]; then
        options='(Y/n)'
    fi

    local confirm
    read -p "$question $options: " "${-+confirm}"
    confirm="${confirm:-$default}"

    if [[ "${confirm,,}" =~ .*[n].* ]]; then
        # no: 1
        return 1
    else
        # yes: 0
        return 0
    fi
}

function _unalias() {
    # Will be unaliased on next refresh
    local cmd="$1"
    sed -i -E "/alias\s+$cmd/d" "$MON_RC_FILE"
    echo "$cmd" >>"$MON_TO_UNALIAS"
}

function _unhash() {
    # Will be unhashed on next refresh
    local cmd="$1"
    echo "$cmd" >>"$MON_TO_UNHASH"
}

function _unregister() {
    if [ "$#" -eq 0 ]; then
        echo "mon: missing argument for 'unregister'"
        echo "'unregister' requires at least 1 argument, you provided $#"
        return 1
    fi

    local args=()
    local question
    if [[ $# -eq 1 ]] && [[ $1 = "--alias" || $1 = "--bin" || $1 = "--all" ]]; then
        if [[ $1 = "--alias" ]]; then
            read -d '\n' -a args <<<"$(_list_alias)"
            question="Unregister all aliases?"

        elif [[ $1 = "--bin" ]]; then
            read -d '\n' -a args <<<"$(_list_bin)"
            question="Unregister all binaries?"

        elif [[ $1 = "--all" ]]; then
            read -d '\n' -a args <<<"$(_list_full)"
            question="Unregister all commands?"
        fi

        if ! _has_confirmed "$question" 'y'; then
            echo "Aborting unregister..."
            return 1
        fi
    else
        args=("$@")
    fi

    local arg
    for arg in "${args[@]}"; do
        local cmd="$arg"

        if ! _is_registered "$cmd"; then
            _not_found_msg "$cmd"
            return 1
        fi

        if _is_alias "$cmd"; then
            _unalias "$cmd"
        else
            _unhash "$cmd"
        fi

        local location="$(_registered_dir $cmd)"
        rm "$location/$cmd"
        rm -f "$MON_COMPLETIONS/$cmd"
        echo "Unregistered command '$cmd'"
    done

    echo "Refresh commands with \`mon refresh\`"

}

function _check() {
    echo "============= .rc file ($MON_RC_FILE) ============="
    echo -e "$(cat $MON_RC_FILE)\n"

    echo "============= .config file ($MON_CONFIG_FILE) ============="
    echo -e "$(cat $MON_CONFIG_FILE)\n"

    echo "============= registered ($MON_REGISTERED) ============="
    echo -e "$alias_title"
    echo -e "$(ls -l $MON_REGISTERED_ALIAS)\n"
    echo -e "$bin_title"
    echo -e "$(ls -l $MON_REGISTERED_BIN)\n"

    echo "============= completions ($MON_COMPLETIONS) ============="
    echo -e "$(ls -l $MON_COMPLETIONS)\n"
}

function _edit() {
    # Edit registered dir
    if [[ "$#" -eq 0 ]]; then
        _open_file "$MON_REGISTERED"
        return 0
    fi

    # Edit monkeypatsh itself
    if [[ "$#" -eq 1 && "$1" = 'mon' ]]; then
        # "$_editor" "$MON_DIR/monkeypat.sh"
        _open_file "$MON_DIR"
        return 0
    fi

    # Edit .monrc and .monconfig
    if [[ "$1" = "-r" || "$1" = "--rc" ]]; then
        _open_file "$MON_RC_FILE"
        return 0
    fi
    if [[ "$1" = "-c" || "$1" = "--config" ]]; then
        _open_file "$MON_CONFIG_FILE"
        return 0
    fi

    local cmd="$1"
    local location="$(_registered_dir $cmd)"

    # Edit cmd
    if [ "$#" -eq 1 ]; then
        if ! _is_registered "$cmd"; then
            _not_found_msg "$cmd"
            exit 1
        fi

        _open_file "$location/$cmd" '_mon_default'
        return 0

    fi

    # Edit patch
    if [ "$#" -eq 2 ]; then
        local opt="$2"
        local opt_function="_mon_$opt"
        if _has_patch "$cmd" "$opt"; then
            _open_file "$location/$cmd" "$opt_function"
            return 0
        else
            _dont_has_patch_msg "$cmd" "$opt"
            return 1
        fi
    fi
}

function _list_alias() {
    local aliases="$(find "$MON_REGISTERED_ALIAS" -type f | xargs -I {} basename {} | sort)"
    if [ -n "$aliases" ]; then
        echo "$aliases"
    fi
}

function _list_bin() {
    local bins="$(find "$MON_REGISTERED_BIN" -type f | xargs -I {} basename {} | sort)"
    if [ -n "$bins" ]; then
        echo "$bins"
    fi
}

function _pretty_bullet_cmd() {
    printf "│› %s\n" "$1"
}

function _pretty_bullet_patch() {
    printf "│  ├─ %s\n" "$1"
}

function _pretty_bullet_patch_last() {
    printf "│  ╰─ %s\n" "$1"
}

function _list_full() {
    if [ "$#" -eq 1 ] && [[ "$1" = "-v" || "$1" = "--verbose" ]]; then
        local aliases="$(_list_alias)"
        local bins="$(_list_bin)"

        if [[ -n "$aliases" ]]; then
            echo -e "$alias_title"
            local alias
            echo "$aliases" | while read -r alias; do
                _pretty_bullet_cmd "$alias"
            done
        fi

        if [[ -n "$aliases" && -n "$bins" ]]; then
            echo ""
        fi

        if [[ -n "$bins" ]]; then
            echo -e "$bin_title"
            local bin
            echo "$bins" | while read -r bin; do
                _pretty_bullet_cmd "$bin"
            done
        fi
    else
        _list_alias
        _list_bin
    fi
}

function _list() {
    if [ "$#" -eq 0 ]; then
        _list_full --verbose
        return
    fi

    if [ "$#" -eq 1 ] && [[ "$1" = "-f" || "$1" = "--flat" ]]; then
        _list_full
        return
    fi

    if [ "$#" -eq 1 ] && [[ "$1" = "-a" || "$1" = "--alias" ]]; then
        _list_alias
        return
    fi

    if [ "$#" -eq 1 ] && [[ "$1" = "-b" || "$1" = "--bin" ]]; then
        _list_bin
        return
    fi

    if [ "$1" = "-r" ] || [ "$1" = "--recursive" ]; then
        function __list_verbose() {
            local alias_or_bin="$1"
            local cmds
            local title
            if [ "$alias_or_bin" = "alias" ]; then
                cmds="$(_list_alias)"
                title="$alias_title"
            else
                cmds="$(_list_bin)"
                title="$bin_title"
            fi

            if [ -z "$cmds" ]; then
                return
            fi

            echo -e "$title"
            local cmd
            while read -r cmd; do
                _pretty_bullet_cmd "$cmd"
                local patches
                read -d '\n' -a patches <<<"$(_list "$cmd")"
                if [ "${#patches[@]}" -gt 0 ]; then
                    local patch

                    for patch in "${patches[@]:0:${#patches[@]}-1}"; do
                        _pretty_bullet_patch "$patch"
                    done
                    _pretty_bullet_patch_last "${patches[-1]}"
                fi
            done <<<"$cmds"
        }

        local alias_part="$(__list_verbose alias)"
        local bin_part="$(__list_verbose bin)"
        if [[ -n "$alias_part" ]]; then echo "$alias_part"; fi
        if [[ -n "$alias_part" && -n "$bin_part" ]]; then echo ""; fi
        if [[ -n "$bin_part" ]]; then echo "$bin_part"; fi

        return
    fi

    local cmd="$1"
    if _is_registered "$cmd"; then
        local location="$(_registered_dir $cmd)"
        (source "$location/$cmd" && declare -F | sed -nE '/_mon_default/! s/.*_mon_([\w\-]*)/\1/p')
    else
        _not_found_msg "$cmd"
    fi
}

function _uninstall() {
    bash "$MON_DIR/uninstall.sh"
}

function _backup() {
    local backup_file=~/.mon.bak."$(date -I)".tar

    if [[ $# -eq 2 ]] && [[ "$1" = '-f' || "$1" = '--file' ]]; then
        backup_file="$2"
        if [ "${backup_file:0:1}" = '~' ]; then
            backup_file="${2/'~'/$HOME}" # replaces leading '~' for $HOME
        fi
    fi

    if [ -f "$backup_file" ]; then
        echo "There is already a backup at '$backup_file'"

        if ! _has_confirmed "Overwrite?"; then
            echo "Aborting backup..."
            return 1
        fi
    fi

    local mon_rc="$(basename $MON_RC_FILE)"
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
    local mon_rc_bak="$tmp_dir/$(basename $MON_RC_FILE)"
    local mon_config_bak="$tmp_dir/$(basename $MON_CONFIG_FILE)"
    local mon_registered_bak="$tmp_dir/$(basename $MON_REGISTERED)"
    local mon_completions_bak="$tmp_dir/$(basename $MON_COMPLETIONS)"

    tar -xf "$backup_file" -C "$tmp_dir"

    cp "$mon_rc_bak" "$MON_RC_FILE"
    cp "$mon_config_bak" "$MON_CONFIG_FILE"
    cp -r "$mon_registered_bak"/* "$MON_REGISTERED"
    cp -r "$mon_completions_bak"/* "$MON_COMPLETIONS"

    echo "Restored monkeypatsh configuration."
    echo "Refresh commands with \`mon refresh\`"
}

function _refresh() {
    # This is in the API just as a convenience, because
    # every time monkeypatsh is called, it sources .monrc,
    # and there it exports, alias and unalias the necessary stuff.
    echo "Refreshed commands"
}

function _help() {
    cat <<'EOF'
Commands available:
    register <cmd>...                    - Register commands to be wrapped with monkeypatsh, as aliases or binaries.
             | --alias <cmd>...            If no flag is provided, or the flag `--alias` is provided, register commands as aliases.
             | --bin <cmd>...              If the flag `--bin` is provided, register commands as binaries (executables available via PATH).
                                           Since aliases cannot be called by default in scripts, they are a great choice for
                                           patching existing commands in interactive shells. Like registering git, ls, ...
                                           Binaries on the other hand, can be called inside scripts by default, and therefore
                                           are a great choice for new commands.
                                           To change from one registration method to the other, just re-register the commands with
                                           the other flag. For example, if `foo` is registered as an alias `mon register --alias foo`,
                                           to change it to an binary, just run `mon register --bin foo`.

    patch <cmd> <sub> [<code>]           - Patch a sub command or option to the registered command. There are 2 ways.
                                           1) You can add your code inline(*):
                                                mon patch ls foo 'echo foo!!!'
                                                mon patch ls --bar 'echo bar!!!'
                                                (*): Keep your inline code simple. If you want to parse arguments or your
                                                code span multiple lines, use the second format.
                                           2) You can summon your editor[1] and put your code there:
                                                mon patch ls foo
                                                mon patch ls --bar

    unregister <cmd>...                  - Unregister commands. This deletes the wrapper for that command.
               | --all                     By providing `--all`, `--alias` or `--bin` you can unregister all commands at once,
               | --alias                   all alias, or all binaries.
               | --bin

    check                                - [DEV] Quick sanity check.

    edit [<cmd>]                         - Edit a registered command wrapper's or a patch with your preferred code editor[1].
         | [<cmd> <sub>]                   If you don't provide any arguments (`mon edit`) monkeypatsh opens the registered directory.
         | [-c | --config]                 You can quick edit the .monconfig file with the option -c or --config.
         | [-r | --rc]                     And you can also quick edit the .monrc file, although not recommended,
                                           since it is automatically generated.
                                           If you want to edit mon source code itself you can do `mon edit mon`.

    list [<cmd>]                         - List registered commands and patches.
         | [-a | --alias]                  If no commands or flags are provided, list all registered commands.
         | [-b | --bin]                    If a `<cmd>` is provided, list its patches.
         | [-f | --flat]                   If `-a` or `--alias` is provided, list registered alias.
         | [-r | --recursive]              If `-b` or `--bin` is provided, list registered binaries.
                                           By default, the list for registered commands nicely distinguish aliases from binaries,
                                           provide `-f` or `--flat` to get a flat list.
                                           If `-r` or `--recursive` is provided, list registered commands and their patches.

    uninstall                            - Uninstall monkeypatsh. Can also be run as `bash uninstall.sh` from
                                           the source dir.

    backup [-f | --file <file>]          - Backup monkeypatsh into a restorable file.
	                                       If -f or --file is not provided, backups into ~/.mon.bak.tar

    restore <file>                       - Restore monkeypatsh from file.

    refresh                              - Refresh commands.

Options available:
    -h|--help                            - Show this help and exit. Can also be shown with just `mon`

Configuring monkeypatsh:
    You can configure how monkeypatsh behaves tweaking configs in the ~/.monconfig file.

    [1] Changing default code editor: `editor = <editor>`

EOF
}

function mon() {
    local mon_cmd="$1"
    if [ -z "$mon_cmd" ]; then
        _help
        return
    fi

    shift
    case "$mon_cmd" in
    reg | regi | regis | regist | registe | register)
        _register "$@"
        ;;
    pat | patc | patch)
        _patch "$@"
        ;;
    unr | unre | unreg | unregi | unregis | unregist | unregiste | unregister)
        _unregister "$@"
        ;;
    che | chec | check)
        _check
        ;;
    edi | edit)
        _edit "$@"
        ;;
    lis | list)
        _list "$@"
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
    ref | refr | refre | refres | refresh)
        _refresh
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
