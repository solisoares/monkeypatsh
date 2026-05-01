#!/usr/bin/env bash

SOURCE_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))"
source $SOURCE_DIR/../common.sh

alias_title="\
╭───────╮
│ Alias │
├───────╯"

bin_title="\
╭───────╮
│  Bin  │
├───────╯"

function _not_registered_msg() {
    local cmd="$1"
    echo "there is no registered command named '$cmd'"
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

function _registered_dir() {
    local cmd="$1"

    if ! _is_registered "$cmd"; then
        return 1
    fi

    if _is_alias "$cmd"; then
        echo "$MON_REGISTERED_ALIAS"
    else
        echo "$MON_REGISTERED_BIN"
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
        _error "register" "missing argument for 'register'"
        _error_hint "'register' requires at least 1 argument, you provided $#"
        return 1
    fi

    local location
    case "$1" in
    -b | --bin)
        location="$MON_REGISTERED_BIN"
        shift
        ;;
    -a | --alias)
        location="$MON_REGISTERED_ALIAS"
        shift
        ;;
    *)
        local register_mode="$(__parse_config 'register_mode')"
        if [[ "$register_mode" = 'bin' ]]; then
            location="$MON_REGISTERED_BIN"
        else
            location="$MON_REGISTERED_ALIAS"
        fi
        ;;
    esac

    local cmds=("$@")

    local cmd
    for cmd in "${cmds[@]}"; do
        if [ "$cmd" = "mon" ]; then
            _error "register" "monkeypatsh cannot be registered."
            return 1
        fi

        if [[ "$cmd" == -* || "$cmd" == *" "* ]]; then
            local cmd_cleaned="${cmd//-/}"
            cmd_cleaned="${cmd_cleaned// /}"

            _error "register" "cannot register a command like '$cmd'"
            _error_hint "Try 'mon register $cmd_cleaned'"
            return 1
        fi

        local old_location
        local changed_location=0

        if _is_registered "$cmd"; then
            old_location="$(_registered_dir $cmd)"
            if [ "$location" = "$old_location" ]; then
                _error "register" "$(_is_registered_msg $cmd)"
                return 1
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

            _info "$(_is_registered_msg $cmd)"
            if ! _has_confirmed "Change to $change_type?"; then
                _info "Aborting change..."
                continue
            fi

            mv "$old_location/$cmd" "$location/$cmd"

            if [ "$location" = "$MON_REGISTERED_BIN" ]; then
                _unalias "$cmd"
            fi

            _info "'$cmd' updated to $change_type."
        fi

        if [[ "$location" = "$MON_REGISTERED_ALIAS" ]]; then
            echo "alias $cmd=$MON_REGISTERED_ALIAS/$cmd" >>$MON_RC_FILE
        fi

        if [ "$changed_location" -eq 1 ]; then
            continue
        fi

        local completion_template
        local register_template

        if command -v "$cmd" >/dev/null; then
            register_template="$MON_TEMPLATES/register_existent_cmd.sh"
            completion_template_bash="$MON_TEMPLATES_COMPLETIONS_BASH/existent_cmd_completion.sh"
            completion_template_zsh="$MON_TEMPLATES_COMPLETIONS_ZSH/existent_cmd_completion.sh"
        else
            register_template="$MON_TEMPLATES/register_new_cmd.sh"
            completion_template_bash="$MON_TEMPLATES_COMPLETIONS_BASH/new_cmd_completion.sh"
            completion_template_zsh="$MON_TEMPLATES_COMPLETIONS_ZSH/new_cmd_completion.sh"
        fi

        export cmd
        # Render registered template
        _render "$register_template" 'cmd' "$cmd" >"$location/$cmd"
        chmod +x "$location/$cmd"
        # Render completion template
        _render "$completion_template_bash" 'cmd' "$cmd" >"$MON_COMPLETIONS_BASH/$cmd"
        _render "$completion_template_zsh" 'cmd' "$cmd" >"$MON_COMPLETIONS_ZSH/$cmd"

        echo "$cmd" >>"$MON_TO_REFRESH_COMPLETION"

        if [[ "$location" = "$MON_REGISTERED_ALIAS" ]]; then
            _info "Registered alias command '$cmd'"
        else
            _info "Registered binary command '$cmd'"
        fi
    done
}

function __parse_config() {
    local config="$1"

    if [[ ! -f "$MON_CONFIG_FILE" ]]; then
        _error "config" "'$MON_CONFIG_FILE' no such file"
        exit 1
    fi

    value="$(
        cat $MON_CONFIG_FILE |
            grep -v '^[[:space:]]*#' |
            grep -E "$config[[:space:]]*=" |
            sed -E "s/.*$config[[:space:]]*=[[:space:]]*([a-zA-Z0-9_]+).*/\1/"
    )"

    echo "$value"
}

function _open_file() {
    local file="$1"
    local pattern="$2"

    local config_editor="$(__parse_config 'editor')"

    if [[ -z "$config_editor" ]] && [[ -n "$EDITOR" ]] && ! command -v "$EDITOR" >/dev/null; then
        _error "config" "'$EDITOR' not found"
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

    local line="$(__get_pattern_line "$pattern" "$file")"

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
        "$editor" --goto "$file:$line"
        ;;
    kate)
        "$editor" --line "$line" "$file"
        ;;
    subl)
        "$editor" "$file:$line"
        ;;
    zed)
        "$editor" "$file:$line"
        ;;
    esac

}

function _has_patch() {
    local cmd="$1"
    local sub="$2"
    if [[ "$(__list_cmd "$cmd" | grep -- "^$sub$")" = "$sub" ]]; then
        return 0
    fi
    return 1
}

function _has_patch_msg() {
    local cmd="$1"
    local patch="$2"
    echo "'$cmd $patch' already exist"
}

function _dont_has_patch_msg() {
    local cmd="$1"
    local patch="$2"

    local not_found='subcommand'
    if [[ "$patch" == -* ]]; then
        not_found='option'
    fi

    echo "'$cmd' has no $not_found named '$patch'"
}

function _patch() {
    # Patch an option or sub command (`opt`) to the registered command
    local cmd="$1"
    local opt="$2"
    local code="$3"

    if [[ "$#" -le 1 ]]; then
        _error "patch" "missing argument for 'patch'"
        _error_hint "'patch' requires at least 2 arguments, you provided $#"
        return 1
    fi

    if ! _is_registered "$cmd"; then
        _error "patch" "$(_not_registered_msg "$cmd")"
        return 1
    fi

    local location="$(_registered_dir "$cmd")"

    if _has_patch "$cmd" "$opt"; then
        _error "patch" "$(_has_patch_msg "$cmd" "$opt")"
        return 1
    fi


    local file_content="$(<"$location/$cmd")"

    # Add patch function
    local patch_function_template="$MON_TEMPLATES/patch_cmd_function.sh"
    if [ -z "$code" ]; then
        patch_function_template="$MON_TEMPLATES/patch_new_cmd_function_empty.sh"
        if command -v "$cmd" >/dev/null; then
            patch_function_template="$MON_TEMPLATES/patch_existent_cmd_function_empty.sh"
        fi
    fi
    local patch_function="$(_render "$patch_function_template" 'cmd' 'opt' 'code' "$cmd" "$opt" "$code")"
    local shebang="\#!/usr/bin/env bash"
    file_content="${file_content/${shebang}/${patch_function}}"

    # Add new case statement
    local patch_case="$(_render "$MON_TEMPLATES/patch_cmd_case.sh" 'opt' "$opt")"
    local case_statement='case "$opt" in'
    file_content="${file_content/${case_statement}/${patch_case}}"

    echo "$file_content" > "$location/$cmd"

    if [ -z "$code" ]; then
        local patch="_mon_$opt"
        _open_file "$location/$cmd" "$patch"
        [[ "$?" -eq 1 ]] && return 1
    fi

    _info "Patched: $cmd $opt"
}

function _has_confirmed() {
    local question="$1"
    local default="$(echo "${2:-y}" | tr '[:upper:]' '[:lower:]')"

    local options='(y/N)'
    if [[ "$default" = 'y' ]]; then
        options='(Y/n)'
    fi

    local confirm
    read -p "$question $options: " "${-+confirm}"
    local confirm="$(echo "${confirm:-$default}" | tr '[:upper:]' '[:lower:]')"

    if [[ "$confirm" =~ .*[n].* ]]; then
        # no: 1
        return 1
    else
        # yes: 0
        return 0
    fi
}

function _unalias() {
    # Will be unaliased on next mon call
    local cmd="$1"
    local sed_flags=("-i")
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed_flags=("-i" "")
    fi
    sed "${sed_flags[@]}" -E "/alias[[:space:]]+$cmd/d" "$MON_RC_FILE"
    echo "$cmd" >>"$MON_TO_UNALIAS"
}

function _unhash() {
    # Will be unhashed on next mon call
    local cmd="$1"
    echo "$cmd" >>"$MON_TO_UNHASH"
}

function _unregister() {
    if [ "$#" -eq 0 ]; then
        _error "unregister" "missing argument for 'unregister'"
        _error_hint "'unregister' requires at least 1 argument, you provided $#"
        return 1
    fi

    local args=()
    local question
    if [[ $# -eq 1 ]] && [[ $1 = "--alias" || "$1" = "-a" || $1 = "--bin" || "$1" = "-b" || $1 = "--all" || "$1" = "-A" ]]; then
        if [[ $1 = "--alias" || "$1" = "-a" ]]; then
            if [[ -z "$(__list_alias)" ]]; then
                _info "No registered aliases"
                return
            fi
            read -d '\n' -a args <<<"$(__list_alias)"
            question="Unregister all aliases?"

        elif [[ $1 = "--bin" || "$1" = "-b" ]]; then
            if [[ -z "$(__list_bin)" ]]; then
                _info "No registered binaries"
                return
            fi
            read -d '\n' -a args <<<"$(__list_bin)"
            question="Unregister all binaries?"

        elif [[ $1 = "--all" || "$1" = "-A" ]]; then
            if [[ -z "$(__list_full)" ]]; then
                _info "No registered commands"
                return
            fi
            read -d '\n' -a args <<<"$(__list_full)"
            question="Unregister all commands?"
        fi

        if ! _has_confirmed "$question" 'y'; then
            _info "Aborting unregister..."
            return
        fi
    else
        args=("$@")
    fi

    local arg
    for arg in "${args[@]}"; do
        local cmd="$arg"

        if ! _is_registered "$cmd"; then
            _error "unregister" "$(_not_registered_msg "$cmd")"
            return 1
        fi

        if _is_alias "$cmd"; then
            _unalias "$cmd"
        else
            _unhash "$cmd"
        fi

        local location="$(_registered_dir $cmd)"
        rm "$location/$cmd"
        rm -f "$MON_COMPLETIONS_BASH/$cmd"
        rm -f "$MON_COMPLETIONS_ZSH/$cmd"
        _info "Unregistered command '$cmd'"
    done
}

function __check() {
    # Quick sanity check.
    _info "============= .rc file ($MON_RC_FILE) ============="
    _info "$(cat $MON_RC_FILE)\n"

    _info "============= .config file ($MON_CONFIG_FILE) ============="
    _info "$(cat $MON_CONFIG_FILE)\n"

    _info "============= registered ($MON_REGISTERED) ============="
    _info "$alias_title"
    _info "$(ls -l $MON_REGISTERED_ALIAS)\n"
    _info "$bin_title"
    _info "$(ls -l $MON_REGISTERED_BIN)\n"

    _info "============= completions ($MON_COMPLETIONS_BASH) ============="
    _info "$(ls -l $MON_COMPLETIONS_BASH)\n"

    _info "============= completions ($MON_COMPLETIONS_ZSH) ============="
    _info "$(ls -l $MON_COMPLETIONS_ZSH)\n"
}

function _edit() {
    # Edit registered dir
    if [[ "$#" -eq 0 ]]; then
        _open_file "$MON_REGISTERED"
        return "$?"
    fi

    # Edit monkeypatsh itself
    if [[ "$#" -eq 1 && "$1" = 'mon' ]]; then
        _open_file "$MON_DIR"
        return "$?"
    fi

    # Edit .monrc and .monconfig
    if [[ "$1" = "-r" || "$1" = "--rc" ]]; then
        _open_file "$MON_RC_FILE"
        return "$?"
    fi
    if [[ "$1" = "-c" || "$1" = "--config" ]]; then
        _open_file "$MON_CONFIG_FILE"
        return "$?"
    fi

    local cmd="$1"
    local location="$(_registered_dir "$cmd")"

    # Edit cmd
    if [ "$#" -eq 1 ]; then
        if ! _is_registered "$cmd"; then
            _error "edit" "$(_not_registered_msg "$cmd")"
            exit 1
        fi

        _open_file "$location/$cmd" '_mon_default'
        return "$?"

    fi

    # Edit patch
    if [ "$#" -eq 2 ]; then
        local opt="$2"
        local opt_function="_mon_$opt"
        if _has_patch "$cmd" "$opt"; then
            _open_file "$location/$cmd" "$opt_function"
            return "$?"
        else
            _error "edit" "$(_dont_has_patch_msg "$cmd" "$opt")"
            return 1
        fi
    fi
}

function __list_alias() {
    local aliases="$(find "$MON_REGISTERED_ALIAS" -type f | xargs -I {} basename {} | sort)"
    if [ -n "$aliases" ]; then
        echo "$aliases"
    fi
}

function __list_bin() {
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

function __list_full() {
    if [ "$#" -eq 1 ] && [[ "$1" = "-p" || "$1" = "--pretty" ]]; then
        local aliases="$(__list_alias)"
        local bins="$(__list_bin)"

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
        __list_alias
        __list_bin
    fi
}

function __list_cmd() {
    local cmd="$1"
    local location="$(_registered_dir "$cmd")"
    if [[ -z "$location" ]]; then
        exit 1
    fi
    (source "$location/$cmd" && declare -F | sed -nE '/_mon_default/! s/.*_mon_([\w\-]*)/\1/p')
}

function _list() {
    if [[ "$#" -gt 1 ]]; then
        _error "list" "too many arguments for 'list'"
        _error_hint "'list' requires 1 argument, you provided $#"
        return 1
    fi

    # Check default mode for 'mon list'
    if [[ "$#" -eq 0 ]]; then
        local list_mode="$(__parse_config 'list_mode')"
        if [[ ! "$list_mode" =~ flat|pretty|recursive ]]; then
            list_mode='recursive'
        fi
    fi

    # All pretty
    if [[ "$list_mode" = 'pretty' ]] || [[ "$#" -eq 1 && "$1" =~ -p|--pretty ]]; then
        local list="$(__list_full --pretty)"
        if [[ -n "$list" ]]; then
            echo "$list"
        else
            _info "No registered commands"
        fi
        return
    fi

    # All flat
    if [[ "$list_mode" = 'flat' ]] || [[ "$#" -eq 1 && "$1" =~ -f|--flat ]]; then
        local list="$(__list_full)"
        if [[ -n "$list" ]]; then
            echo "$list"
        else
            _info "No registered commands"
        fi
        return
    fi

    # All recursive pretty
    if [[ "$list_mode" = 'recursive' ]] || [[ "$#" -eq 1 && "$1" =~ -r|--recursive ]]; then
        function __list_full_verbose() {
            local alias_or_bin="$1"
            local cmds
            local title
            if [ "$alias_or_bin" = "alias" ]; then
                cmds="$(__list_alias)"
                title="$alias_title"
            else
                cmds="$(__list_bin)"
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
                read -d '\n' -a patches <<<"$(__list_cmd "$cmd")"
                if [ "${#patches[@]}" -gt 0 ]; then
                    local patch

                    for patch in "${patches[@]:0:${#patches[@]}-1}"; do
                        _pretty_bullet_patch "$patch"
                    done
                    _pretty_bullet_patch_last "${patches[${#patches[@]} - 1]}"
                fi
            done <<<"$cmds"
        }

        local alias_part="$(__list_full_verbose alias)"
        local bin_part="$(__list_full_verbose bin)"
        if [[ -z "$alias_part" && -z "$bin_part" ]]; then _info "No registered commands"; fi
        if [[ -n "$alias_part" ]]; then _info "$alias_part"; fi
        if [[ -n "$alias_part" && -n "$bin_part" ]]; then _info ""; fi
        if [[ -n "$bin_part" ]]; then _info "$bin_part"; fi

        return
    fi

    # Aliases
    if [ "$#" -eq 1 ] && [[ "$1" = "-a" || "$1" = "--alias" ]]; then
        local list="$(__list_alias)"
        if [[ -n "$list" ]]; then
            echo "$list"
        else
            _info "No registered aliases"
        fi
        return
    fi

    # Binaries
    if [ "$#" -eq 1 ] && [[ "$1" = "-b" || "$1" = "--bin" ]]; then
        local list="$(__list_bin)"
        if [[ -n "$list" ]]; then
            echo "$list"
        else
            _info "No registered binaries"
        fi
        return
    fi

    # Cmd
    local cmd="$1"
    if _is_registered "$cmd"; then
        local patches="$(__list_cmd "$cmd")"
        if [[ -z "$patches" ]]; then
            _info "No patches"
        else
            __list_cmd "$cmd"
        fi
    else
        _error "list" "$(_not_registered_msg "$cmd")"
        return 1
    fi
}

function _uninstall() {
    bash "$MON_DIR/uninstall.sh"
}

function _backup() {
    local backup_file=~/.mon.bak."$(date -I)".tar

    if [[ "$#" -eq 1 ]]; then
        _error "backup" "wrong syntax for 'backup'"
        _error_hint "See 'mon help'."
        return 1
    fi

    if [[ $# -eq 2 ]] && [[ "$1" = '-f' || "$1" = '--file' ]]; then
        backup_file="$2"
        if [ "${backup_file:0:1}" = '~' ]; then
            backup_file="${2/'~'/$HOME}" # replaces leading '~' for $HOME
        fi
    fi

    if [ -f "$backup_file" ]; then
        _info "There is already a backup at '$backup_file'"

        if ! _has_confirmed "Overwrite?"; then
            _info "Aborting backup..."
            return
        fi
    fi

    local mon_rc="$(basename $MON_RC_FILE)"
    local mon_config="$(basename $MON_CONFIG_FILE)"
    local mon_registered="$(basename $MON_DIR)/$(basename $MON_REGISTERED)"

    # Contents of the <backup> file:
    # 	.monrc
    # 	.monconfig
    # 	registered/
    # 		\_ alias
    # 		    \_ <cmd_1>
    # 		    \_ ...
    # 		\_ bin
    # 		    \_ <cmd_2>
    # 		    \_ ...
    #   completions/
    #       \_ bash
    #           \_ mon
    #           \_ <cmd_1>
    #           \_ ...
    #       \_ zsh
    #           \_ mon
    #           \_ <cmd_1>
    #           \_ ...
    tar -cf "$backup_file" -C ~ "$mon_rc" "$mon_config"
    tar -uf "$backup_file" -C "$MON_DIR" "$(basename $MON_REGISTERED)" >/dev/null 2>&1
    tar -uf "$backup_file" -C "$MON_DIR" --exclude="mon" "$(basename $MON_COMPLETIONS)" >/dev/null 2>&1

    _info "Backed up monkeypatsh."
    _info "To restore run: 'mon restore $backup_file'"
}

function _restore() {
    if [ $# -eq 0 ]; then
        _error "restore" "missing argument for 'restore'"
        _error_hint "'restore' requires a backup file: 'mon restore <file.bak.tar>'"
        return 1
    fi

    local backup_file="$1"
    if [[ ! -e "$backup_file" ]]; then
        _error "restore" "file '$backup_file' does not exist"
        return 1
    fi

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

    _info "Restored monkeypatsh configuration."
    _info "List registered commands with 'mon list'"
}

function __help_register() {
    cat <<'EOF'
register <cmd>...
         | [-a | --alias] <cmd>...
         | [-b | --bin] <cmd>...

      Register commands to be wrapped with monkeypatsh as aliases or binaries.

      -a, --alias   Register as a shell alias. Since aliases cannot be called
                    by default in scripts, they are a great choice for patching
                    existing commands in interactive shells, like git, ls ...
      -b, --bin     Register as a binary (executable on PATH). Binaries work
                    inside scripts and are ideal for entirely new commands.

      If no flag is given, --alias is assumed. To change this default, change
      'register_mode' in ~/.monconfig (mon edit --config):

          register_mode=alias|bin

      To switch a command from alias to bin (or vice versa), re-register it
      with the desired flag:

          mon register --alias foo # register as alias
          mon register --bin foo   # re-register as binary
EOF
}

function __help_patch() {
    cat <<'EOF'
patch <cmd> <sub> [<code>]
      Add a subcommand or option patch to a registered command.

      Interactive (opens your editor):
          mon patch ls foo
          mon patch ls --bar

      Inline (for simple one-liners):
          mon patch ls foo 'echo foo!'
          mon patch ls --bar 'echo bar!'
EOF
}

function __help_unregister() {
    cat <<'EOF'
unregister <cmd>...
           | [ -A | --all]
           | [ -a | --alias]
           | [ -b | --bin]

      Unregister commands, deleting their monkeypatsh wrappers.

      -A, --all     Unregister all registered commands.
      -a, --alias   Unregister all registered aliases.
      -b, --bin     Unregister all registered binaries.
EOF
}

function __help_list() {
    cat <<'EOF'
list [<cmd>]
     | [-a | --alias]
     | [-b | --bin]
     | [-f | --flat]
     | [-p | --pretty]
     | [-r | --recursive]

      List registered commands and their patches.

      (no args)       List all commands and their patches with visual alias/bin grouping. (default).
      <cmd>           List patches for the given command.
      -a, --alias     List only registered aliases.
      -b, --bin       List only registered binaries.
      -f, --flat      List all commands as a plain flat list.
      -p, --pretty    List all commands with visual alias/bin grouping.
      -r, --recursive List all commands and their patches with visual alias/bin grouping.

      To change what 'mon list' does with no arguments, change 'list_mode'
      in ~/.monconfig (mon edit --config):

          list_mode=pretty|flat|recursive
EOF
}

function __help_edit() {
    cat <<'EOF'
edit [<cmd>]
     | [<cmd> <sub>]
     | [-c | --config]
     | [-r | --rc]

      Open a registered command wrapper or patch in your editor.

      (no args)       Open the registered commands directory.
      <cmd>           Edit the wrapper for <cmd>.
      <cmd> <sub>     Edit the patch <sub> within <cmd>.
      -c, --config    Edit ~/.monconfig directly.
      -r, --rc        Edit ~/.monrc directly (auto-generated, edit with care).

      If you want to add monkeypatsh source code, you can quickly do so with
      'mon edit mon'.
EOF
}

function __help_backup() {
    cat <<'EOF'
backup [-f | --file <file>]

      Back up monkeypatsh configuration into a restorable archive.
      Defaults to ~/.mon.bak.<date>.tar

      -f, --file <file>   Write the backup to <file>.
EOF
}

function __help_restore() {
    cat <<'EOF'
restore <file>
      Restore monkeypatsh configuration from a backup archive.
EOF
}

function __help_uninstall() {
    cat <<'EOF'
uninstall
      Uninstall monkeypatsh. Equivalent to running `bash uninstall.sh` from
      the source directory.
EOF
}

function __help_version() {
    cat <<'EOF'
version | -v | --version
      Print the current version of monkeypatsh.
EOF
}

function __help_help() {
    cat <<'EOF'
help [-s|--short] [<cmd>]
      Show help and exit.

      -s, --short   Show a brief summary of commands and options.
EOF
}

function __help_help_flag() {
    cat <<'EOF'
-h, --help [-s|--short] [<cmd>]
      Show help and exit.

      -s, --short   Show a brief summary of commands and options.
EOF
}

function __help_configuration() {
    cat <<'EOF'
Behavior defaults can be changed in ~/.monconfig (edit with: mon edit --config).
Settings below only affect default behavior when no flags are provided; use
explicit flags to override at any time.

register_mode = alias|bin
    Controls what 'mon register <cmd>' does without a flag.
    Defaults to 'alias'.

    Monkeypatsh was built around the idea of patching existing
    commands, so by default, it register aliases.

    alias  -  Register shell alias (good for patching existing tools).
    bin    -  Register binaries    (good for creating new commands).

list_mode = pretty|flat|recursive
    Controls what 'mon list' displays without a flag.
    Defaults to 'recursive'.

    pretty     - Visual alias/bin grouping.
    flat       - Plain list of all command names.
    recursive  - All commands with their patches expanded.

editor = <editor>
    Editor used when opening files interactively (patch, edit).
    Defaults to '$EDITOR' or 'vi'
EOF
}

function _help() {
    if [[ "$1" =~ -s|--short ]]; then
        _help_short
        return
    fi

    local help_cmd="$1"
    if [ -n "$help_cmd" ]; then
        case "$help_cmd" in
        reg | regi | regis | regist | registe | register) __help_register ;;
        pat | patc | patch) __help_patch ;;
        unr | unre | unreg | unregi | unregis | unregist | unregiste | unregister) __help_unregister ;;
        lis | list) __help_list ;;
        edi | edit) __help_edit ;;
        bac | back | backu | backup) __help_backup ;;
        res | rest | resto | restor | restore) __help_restore ;;
        uni | unin | unins | uninst | uninsta | uninstal | uninstall) __help_uninstall ;;
        ver | vers | versi | versio | version | -v | --version) __help_version ;;
        hel | help | -h | --help) __help_help ;;
        *)
            _error "" "unrecognized command '$help_cmd'"
            _error_hint "Try 'mon help' for more information."
            return 1
            ;;
        esac
        return
    fi

    echo "Usage:  mon <command> [options]"
    echo "        mon [-v | --version | version]"
    echo "        mon [-h | --help | help] [-s|--short] [<command>]"
    echo ""

    echo "Commands:"
    {
        __help_register
        echo ""
        __help_patch
        echo ""
        __help_unregister
        echo ""
        __help_list
        echo ""
        __help_edit
        echo ""
        __help_backup
        echo ""
        __help_restore
        echo ""
        __help_uninstall
        echo ""
        __help_version
        echo ""
        __help_help
        echo ""
    } | sed 's/^/  /'

    echo "Options:"
    __help_help_flag | sed 's/^/  /'
    echo ""

    echo "Configuration:"
    __help_configuration | sed 's/^/  /'
}

function _help_short() {
    cat <<'EOF'
Usage:  mon <command> [options]

Commands:
  register    Register commands as aliases or binaries
  patch       Add a subcommand or option patch to a registered command
  unregister  Unregister commands and delete their wrappers
  list        List registered commands and their patches
  edit        Edit a command wrapper, patch, or config
  backup      Back up monkeypatsh configuration
  restore     Restore configuration from a backup archive
  uninstall   Uninstall monkeypatsh
  version     Print the current version
  help        Show help and exit

Full help: `mon help`.
Help for a specific command: `mon help <cmd>`.
EOF
}

function _version() {
   echo "Monkeypatsh $MON_VERSION"
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
    hel | help | -h | --help | -hs | -sh)
        if [[ "$mon_cmd" =~ -hs|-sh ]]; then
            _help --short
            return
        fi
        _help "$@"
        ;;
    ver | vers | versi | versio | version | -v | --version)
        _version
        ;;

    # Not exposed in help: dev commands or used in completions
    __check)
        __check
        ;;
    __is_registered)
        _is_registered "$@"
        ;;
    __list_full)
        __list_full "$@"
        ;;
    __list_alias)
        __list_alias "$@"
        ;;
    __list_bin)
        __list_bin "$@"
        ;;
    __list_cmd)
        __list_cmd "$@"
        ;;
    *)
        _error "" "unrecognized command '$mon_cmd'"
        _error_hint "Try 'mon help' for more information."
        return 1
        ;;
    esac
}

mon "$@"
