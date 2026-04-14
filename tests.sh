#!/usr/bin/env bash

# ----------------------------------------------------------------------------- #
# Tests for monkeypatsh. Run with './tests.sh' or 'bash ./tests.sh'.            #
#                                                                               #
# This script backups the current monkeypatsh state and restores it at the end. #
# It covers the standard flow for monkeypatsh and bash completions.             #
# ----------------------------------------------------------------------------- #

SOURCE_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))"
source $SOURCE_DIR/common.sh

trap "__sig_handler_util" SIGINT SIGTERM

export MON_TESTING=1

function _is_equal() {
    local expected="$1"
    local real="$2"
    local msg="$3"

    if [ "$expected" = "$real" ]; then
        __log_util --success "$msg"
    else
        __log_util --fail "$msg"
    fi
}

function _mon() {
    if [ "$1" = "list" ]; then
        _error "$0" "use '_mon_list' to get list output" >&2
        exit 1
    fi
    monkeypat.sh "$@" >/dev/null 2>&1
    return "$?"
}

function _mon_list() {
    case "$1" in
    -a | --alias | -b | --bin | -f | --flat | __test_cmd*)
        monkeypat.sh list "$@"
        ;;
    *)
        _error "$0" "'$1' is not a valid option for '_mon_list'" >&2
        exit 1
        ;;
    esac
}

function __log_util() {
    local kind="$1"
    shift

    __update_counts_util

    if [[ "$kind" = '--fail' ]]; then
        __update_counts_util --fail
        echo -e "[${RED}FAILED${RESET_COLOR}] $@" 1>&2
    elif [[ "$kind" = '--success' ]]; then
        __update_counts_util --success
        echo -e "[${GREEN}PASSED${RESET_COLOR}] $@"
    fi
}

function __update_counts_util() {
    if [[ -z "$1" ]]; then
        tests_count=$((tests_count + 1))
    elif [[ "$1" = '--success' ]]; then
        tests_succeeded=$((tests_succeeded + 1))
    elif [[ "$1" = '--fail' ]]; then
        tests_failed=$((tests_failed + 1))
    fi
}

function __backup_util() {
    echo -e "\n[INFO] Starting backup for current state at '$current_state_backup_file'..."

    monkeypat.sh backup --file "$current_state_backup_file" <<<'y' >/dev/null
    if [[ "$?" -ne 0 ]]; then
        _error "$0" "failed to backup current state, backup exited with error." >&2
        exit 1
    fi

    echo "[INFO] Finished backup for current state at '$current_state_backup_file'. Exited with no errors."

    echo "[INFO] Starting check for correct data inside backup..."

    local old_IFS="$IFS"

    expected_str="$(
        cat <<EOF
.monrc
.monconfig
$(find "$MON_REGISTERED"/ -type d)
$(find "$MON_REGISTERED"/ -type f ! -name 'mon')
$(find "$MON_COMPLETIONS"/ -type d)
$(find "$MON_COMPLETIONS"/ -type f ! -name 'mon')
EOF
    )"

    local expected=()
    local expected_line=""
    while read -r expected_line; do
        if [[ -n "$expected_line" ]]; then
            local _expected_line="${expected_line#$MON_DIR/}"
            expected+=("${_expected_line%/}")
        fi
    done <<<"$expected_str"

    IFS=$'\n' expected=($(sort <<<"${expected[*]}"))

    real=()
    real_line=""
    while read -r real_line; do
        if [[ -n "$real_line" ]]; then
            local _real_line="${real_line#$MON_DIR/}"
            real+=("${_real_line%/}")
        fi
    done < <(tar --list -f "$current_state_backup_file" | sort)

    IFS=$'\n' real=($(sort <<<"${real[*]}"))
    IFS="$old_IFS"

    if [[ "${#expected[@]}" -ne "${#real[@]}" ]]; then
        _error "$0" "failed to backup current state" >&2
        _error_hint "The backup at '$current_state_backup_file' didn't match the current state" >&2
        exit 1
    fi

    local i
    for i in "${!expected[@]}"; do
        # Sanity check:
        # echo "[$i] | expected: ${expected[$i]} | real: ${real[$i]}"
        if [[ "${expected[$i]}" != "${real[$i]}" ]]; then
            _error "$0" "failed to backup current state" >&2
            _error_hint "The backup at '$current_state_backup_file' didn't match the current state" >&2
            exit 1
        fi

    done

    echo "[INFO] Finished check for correct data inside backup. All good."
}

function __restore_util() {
    echo -e "\n[INFO] Starting restore for previous state..."

    monkeypat.sh restore "$current_state_backup_file" >/dev/null
    if [[ "$?" -ne 0 ]]; then
        _error "$0" "failed to restore state at file '$current_state_backup_file'" >&2
        exit 1
    fi

    echo "[INFO] Finished restore for previous state"

    echo "[INFO] Starting removal of previous state backup at '$current_state_backup_file'..."

    __remove_file_util "$current_state_backup_file"

    echo "[INFO] Finished removal of previous state backup at '$current_state_backup_file'"
}

function __register_all_util() {
    monkeypat.sh register --alias __test_cmd1__ __test_cmd2__ __test_cmd3__ __test_cmd4__ __test_cmd5__ >/dev/null 2>&1
    monkeypat.sh register --bin __test_cmd6__ __test_cmd7__ >/dev/null 2>&1
    monkeypat.sh patch __test_cmd1__ --foo "echo 'foo'" >/dev/null 2>&1
}

function __unregister_all_util() {
    monkeypat.sh unregister --all <<<'y' >/dev/null 2>&1
}

function __remove_file_util() {
    rm "$1"
}

function __log_fail_diff_util() {
    local msg="$1"
    local expected="$2"
    local actual="$3"
    __log_util --fail "$msg" \
        "\n~~~~~~~~~~~~~~~~~~~~~~" \
        "\nExpected:" \
        "\n$expected" \
        "\n----------------------" \
        "\nActual:" \
        "\n$actual" \
        "\n~~~~~~~~~~~~~~~~~~~~~~"
}

current_state_backup_file="./__before_test_backup__"
test_backup_file="/tmp/__test_mon_backup__"
tests_count=0
tests_succeeded=0
tests_failed=0

function _test_register() {
    echo -e "\n─── Register ───"

    # Should give success
    _mon register __test_cmd1__
    _is_equal "$?" 0 "register one command with no flag"

    _mon register __test_cmd2__ __test_cmd3__
    _is_equal "$?" 0 "register multiple commands with no flag"

    _mon register --alias __test_cmd4__ __test_cmd5__
    _is_equal "$?" 0 "register multiple alias commands"

    _mon register --bin __test_cmd6__ __test_cmd7__
    _is_equal "$?" 0 "register multiple bin commands"

    _mon register --alias __test_cmd7__ <<<'y'
    _is_equal "$?" 0 "re-register bin command as alias"

    _mon register --bin __test_cmd7__ <<<'y'
    _is_equal "$?" 0 "re-register alias command as bin"

    # Should give error
    _mon register __test_cmd1__
    _is_equal "$?" 1 "cannot re-register command"

    _mon register __test_cmd1__ __test_cmd2__
    _is_equal "$?" 1 "cannot re-register multiple commands"

    _mon register --alias __test_cmd1__
    _is_equal "$?" 1 "cannot re-register alias command"

    _mon register --alias __test_cmd1__ __test_cmd2__
    _is_equal "$?" 1 "cannot re-register multiple alias commands"

    _mon register --bin __test_cmd6__
    _is_equal "$?" 1 "cannot re-register bin command"

    _mon register --bin __test_cmd6__ __test_cmd7__
    _is_equal "$?" 1 "cannot re-register multiple bin commands"

    _mon register --__test_cmd__
    _is_equal "$?" 1 "cannot register command starting with '-'"

    _mon register "__test  cmd__"
    _is_equal "$?" 1 "cannot register command starting with spaces"

}

function _test_patch() {
    echo -e "\n─── Patch ───"

    # Should give success
    _mon patch __test_cmd1__ --foo2 "echo 'foo'"
    _is_equal "$?" 0 "patch command inline"

    # Should give error
    _mon patch __test_cmd_not_registered__ --foo "echo 'foo'"
    _is_equal "$?" 1 "cannot patch non registered command inline"

}

function _test_edit() {
    echo -e "\n─── Edit ───"

    # Should give error
    _mon edit __test_cmd1__ --bar
    _is_equal "$?" 1 "cannot edit non existent patch"

    _mon edit __test_cmd_not_registered__
    _is_equal "$?" 1 "cannot edit non registered command"

    _mon edit __test_cmd_not_registered__ --foo
    _is_equal "$?" 1 "cannot edit non registered command patch"

}

function _test_unregister() {
    echo -e "\n─── Unregister ───"

    # Should give success
    _mon unregister __test_cmd1__
    _is_equal "$?" 0 "unregister command"

    _mon unregister __test_cmd2__ __test_cmd6__
    _is_equal "$?" 0 "unregister multiple commands"

    _mon unregister --alias <<<'y'
    _is_equal "$?" 0 "unregister alias commands"

    _mon unregister --bin <<<'y'
    _is_equal "$?" 0 "unregister bin commands"

    __register_all_util
    _mon unregister --all <<<'y'
    _is_equal "$?" 0 "unregister all commands"

    # Should give error
    _mon unregister __test_cmd_not_registered__
    _is_equal "$?" 1 "cannot unregister non registered command"
}

function _test_backup() {
    echo -e "\n─── Backup ───"
    __register_all_util

    # Should give success
    _mon backup --file "$test_backup_file" <<<'y'
    _is_equal "$?" 0 "backup specific file"
}

function _test_restore() {
    echo -e "\n─── Restore ───"

    # Should give success
    _mon restore "$test_backup_file"
    _is_equal "$?" 0 "restore file"

    __remove_file_util "$test_backup_file"
}

function _test_list() {
    echo -e "\n─── List ───"

    # List aliases
    expected_aliases="\
__test_cmd1__
__test_cmd2__
__test_cmd3__
__test_cmd4__
__test_cmd5__"

    actual_aliases="$(_mon_list --alias)"
    if [[ "$expected_aliases" = "$actual_aliases" ]]; then
        __log_util --success "list alias commands"
    else
        __log_fail_diff_util "failed list alias commands" "$expected_aliases" "$actual_aliases"
    fi

    # List binaries
    expected_bins="\
__test_cmd6__
__test_cmd7__"
    actual_bins="$(_mon_list --bin)"
    if [[ "$expected_bins" = "$actual_bins" ]]; then
        __log_util --success "list bin commands"
    else
        __log_fail_diff_util "failed list bin commands" "$expected_bins" "$actual_bins"
    fi

    # List patches
    expected_patches="\
--foo"
    actual_patches="$(_mon_list __test_cmd1__)"
    if [[ "$expected_patches" = "$actual_patches" ]]; then
        __log_util --success "list command patches"
    else
        __log_fail_diff_util "failed list command patches" "$expected_patches" "$actual_patches"
    fi

    # List unregistered
    _mon_list __test_cmd_not_registered__ 2>/dev/null
    _is_equal "$?" 1 "cannot list non registered command"

}

function _test_bash_completion() {
    echo -e "\n─── Bash Completions ───"

    function __get_compreply() {
        local target_cmd="${1}"
        local completion
        if [[ "$target_cmd" = "mon" ]]; then
            completion="_mon_completion"
        else
            completion="_mon_${target_cmd}_completion"
        fi

        shift
        (
            COMP_WORDS=("$target_cmd" $@)

            COMP_CWORD="$((${#COMP_WORDS[@]} - 1))"

            COMP_LINE="${COMP_WORDS[*]}"
            COMP_POINT="${#COMP_LINE}"

            source "$MON_COMPLETIONS_BASH/${target_cmd}"
            $completion

            echo "${COMPREPLY[@]}"
        )
    }

    # Mon completions ----------------------------
    # First level
    _is_equal "register" \
        "$(__get_compreply 'mon' 'reg')" \
        "completion for 'mon reg[tab] == register'"

    _is_equal "unregister" \
        "$(__get_compreply 'mon' 'unr')" \
        "completion for 'mon unr[tab] == unregister'"

    _is_equal "backup" \
        "$(__get_compreply 'mon' 'bac')" \
        "completion for 'mon bac[tab] == backup'"

    _is_equal "--help" \
        "$(__get_compreply 'mon' '--h')" \
        "completion for 'mon --h[tab] == --help'"

    # Inner levels
    _is_equal "--alias" \
        "$(__get_compreply 'mon' 'register' '--a')" \
        "completion for 'mon register --a[tab] == --alias'"

    _is_equal "--alias" \
        "$(__get_compreply 'mon' 'unregister' '--a')" \
        "completion for 'mon unregister --a[tab] == --alias'"

    _is_equal "__test_cmd1__" \
        "$(__get_compreply 'mon' 'list' '__test_cmd1')" \
        "completion for 'mon list __test_cmd1[tab] == __test_cmd1__'"

    _is_equal "__test_cmd1__" \
        "$(__get_compreply 'mon' 'edit' '__test_cmd1')" \
        "completion for 'mon edit __test_cmd1[tab] == __test_cmd1__'"

    _is_equal "--foo" \
        "$(__get_compreply 'mon' 'edit' '__test_cmd1__' '--f')" \
        "completion for 'mon edit __test_cmd1__ --f[tab] == --foo'"

    _is_equal "__test_cmd1__ __test_cmd2__ __test_cmd3__ __test_cmd4__ __test_cmd5__ __test_cmd6__ __test_cmd7__" \
        "$(__get_compreply 'mon' 'list' '__')" \
        "completion for 'mon list __[tab] == __test_cmd1__ ... __test_cmd7__'"

    _is_equal "" \
        "$(__get_compreply 'mon' 'edit' '__test_cmd_not_registered')" \
        "completion for 'mon edit __test_cmd_not_registered[tab] == null'"

    _is_equal "" \
        "$(__get_compreply 'mon' 'patch' '__test_cmd_not_registered')" \
        "completion for 'mon patch __test_cmd_not_registered[tab] == null'"

    _is_equal "" \
        "$(__get_compreply 'mon' 'edit' '__test_cmd1__' '--non-existent-flag')" \
        "completion for 'mon edit __test_cmd1__ ----non-existent-flag[tab] == null'"

    # Registered command completions -------------
    _is_equal "--foo" \
        "$(__get_compreply '__test_cmd1__' '--f')" \
        "completion for '__test_cmd1__ --f[tab] == --foo'"
}

function __summary_util() {
    if [ "$tests_failed" -eq 0 ]; then
        final_msg="$(echo -e "$GREEN")\
╭────────────────────────────────╮
│       Status: ALL PASSED       │
╰────────────────────────────────╯
$(echo -e "$RESET_COLOR")"
    else
        final_msg="$(echo -e "$RED")\
╭────────────────────────────────╮
│         Status: FAILED         │
╰────────────────────────────────╯
$(echo -e "$RESET_COLOR")"
    fi

    cat <<EOF

╭────────────────────────────────╮
│          TEST RESULTS          │
╰────────────────────────────────╯
  Total:   $tests_count
  Passed:  $tests_succeeded
  Failed:  $tests_failed
$final_msg
EOF
}

function __sig_handler_util() {
    echo -e "\n\n[INFO] Killing '$0' execution"
    __unregister_all_util
    __restore_util
    exit
}

function _tests_run() {
    # Setup
    echo "Starting tests..."
    __backup_util
    __unregister_all_util

    # Test standard flow
    _test_register
    __unregister_all_util
    __register_all_util
    _test_patch
    _test_edit
    _test_unregister
    _test_backup
    _test_restore
    _test_list

    # Test completions
    __unregister_all_util
    __register_all_util
    _test_bash_completion

    # Tear down
    __unregister_all_util
    __restore_util
    __summary_util

}

_tests_run
