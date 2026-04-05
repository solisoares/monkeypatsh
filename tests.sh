#!/usr/bin/env bash

# Basic tests for monkeypatsh.
# This script backups the current monkeypatsh state and restores it at the end.
# It does not cover completions and interactive edits... But it's honest work

SOURCE_DIR="$(realpath $(dirname ${BASH_SOURCE[0]}))"
source $SOURCE_DIR/common.sh

function _check_exit() {
    local expected_exit="$1"
    local real_exit="$2"
    local msg="$3"

    if [ "$expected_exit" = "$real_exit" ]; then
        __log_util --success "$msg"
    else
        __log_util --fail "$msg"
    fi
}

function _mon() {
    if [ "$1" = "list" ]; then
        echo "mon: tests: use '_mon_list' to get list output" >&2
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
        echo "mon: tests: '$1' is not a valid option for '_mon_list'" >&2
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
    echo -e "\n[INFO] Starting backup for current state..."

    monkeypat.sh backup --file "$current_state_backup_file" <<<'y' >/dev/null
    if [[ "$?" -ne 0 ]]; then
        echo "mon: tests: failed to backup current state" >&2
        exit 1
    fi

    echo "[INFO] Finished backup for current state at '$current_state_backup_file'"

    echo "[INFO] Starting unregister for current commands..."
    monkeypat.sh unregister --all <<< 'y' >/dev/null
    if [[ "$?" -ne 0 ]]; then
        echo "mon: tests: failed to unregister current commands" >&2
        exit 1
    fi
    echo "[INFO] Finished unregister for current commands"
}

function __restore_util() {
    echo -e "\n[INFO] Starting restore for previous state..."

    monkeypat.sh restore "$current_state_backup_file" >/dev/null
    if [[ "$?" -ne 0 ]]; then
        echo "mon: tests: failed to restore state at file '$current_state_backup_file'" >&2
        exit 1
    fi

    __remove_file_util "$current_state_backup_file"

    echo "[INFO] Finished restore for previous state"
    echo "[INFO] Removed previous state backup at '$current_state_backup_file'"
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
    _check_exit "$?" 0 "register one command with no flag"

    _mon register __test_cmd2__ __test_cmd3__
    _check_exit "$?" 0 "register multiple commands with no flag"

    _mon register --alias __test_cmd4__ __test_cmd5__
    _check_exit "$?" 0 "register multiple alias commands"

    _mon register --bin __test_cmd6__ __test_cmd7__
    _check_exit "$?" 0 "register multiple bin commands"

    _mon register --alias __test_cmd7__ <<<'y'
    _check_exit "$?" 0 "re-register bin command as alias"

    _mon register --bin __test_cmd7__ <<<'y'
    _check_exit "$?" 0 "re-register alias command as bin"

    # Should give error
    _mon register __test_cmd1__
    _check_exit "$?" 1 "cannot re-register command"

    _mon register __test_cmd1__ __test_cmd2__
    _check_exit "$?" 1 "cannot re-register multiple commands"

    _mon register --alias __test_cmd1__
    _check_exit "$?" 1 "cannot re-register alias command"

    _mon register --alias __test_cmd1__ __test_cmd2__
    _check_exit "$?" 1 "cannot re-register multiple alias commands"

    _mon register --bin __test_cmd6__
    _check_exit "$?" 1 "cannot re-register bin command"

    _mon register --bin __test_cmd6__ __test_cmd7__
    _check_exit "$?" 1 "cannot re-register multiple bin commands"

    _mon register --__test_cmd__
    _check_exit "$?" 1 "cannot register command starting with '-'"

    _mon register "__test  cmd__"
    _check_exit "$?" 1 "cannot register command starting with spaces"

}

function _test_patch() {
    echo -e "\n─── Patch ───"

    # Should give success
    _mon patch __test_cmd1__ --foo "echo 'foo'"
    _check_exit "$?" 0 "patch command inline"

    # Should give error
    _mon patch __test_cmd_not_registered__ --foo "echo 'foo'"
    _check_exit "$?" 1 "cannot patch non registered command inline"

}

function _test_edit() {
    echo -e "\n─── Edit ───"

    # Should give error
    _mon edit __test_cmd1__ --bar
    _check_exit "$?" 1 "cannot edit non existent patch"

    _mon edit __test_cmd_not_registered__
    _check_exit "$?" 1 "cannot edit non registered command"

    _mon edit __test_cmd_not_registered__ --foo
    _check_exit "$?" 1 "cannot edit non registered command patch"

}

function _test_unregister() {
    echo -e "\n─── Unregister ───"

    # Should give success
    _mon unregister __test_cmd1__
    _check_exit "$?" 0 "unregister command"

    _mon unregister __test_cmd2__ __test_cmd6__
    _check_exit "$?" 0 "unregister multiple commands"

    _mon unregister --alias <<<'y'
    _check_exit "$?" 0 "unregister alias commands"

    _mon unregister --bin <<<'y'
    _check_exit "$?" 0 "unregister bin commands"

    __register_all_util
    _mon unregister --all <<<'y'
    _check_exit "$?" 0 "unregister all commands"

    # Should give error
    _mon unregister __test_cmd_not_registered__
    _check_exit "$?" 1 "cannot unregister non registered command"
}

function _test_backup() {
    echo -e "\n─── Backup ───"
    __register_all_util

    # Should give success
    _mon backup --file "$test_backup_file" <<<'y'
    _check_exit "$?" 0 "backup specific file"
}

function _test_restore() {
    echo -e "\n─── Restore ───"
    __unregister_all_util

    # Should give success
    _mon restore "$test_backup_file"
    _check_exit "$?" 0 "restore file"

    __remove_file_util "$test_backup_file"
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
    _check_exit "$?" 1 "cannot list non registered command"

    __unregister_all_util
}

function _tests_run() {
    echo "Starting tests..."

    __backup_util

    _test_register
    _test_patch
    _test_edit
    _test_unregister
    _test_backup
    _test_restore
    _test_list

    __restore_util

    __summary_util

}

_tests_run
