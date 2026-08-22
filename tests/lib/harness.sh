#!/usr/bin/env bash
# Tiny zero-dependency test harness. Source this, then call the assert_* helpers.
# Every assert prints a PASS/FAIL line and bumps the counters. Call `summary` at
# the end and exit with its status.

TESTS_RUN=0
TESTS_FAILED=0
CURRENT_SUITE=''

if [ -t 1 ]; then
    C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'; C_OFF=$'\033[0m'
else
    C_RED=''; C_GREEN=''; C_DIM=''; C_BOLD=''; C_OFF=''
fi

function suite() {
    CURRENT_SUITE="$1"
    printf '\n%s== %s ==%s\n' "$C_BOLD" "$1" "$C_OFF"
}

function pass() {
    TESTS_RUN=$((TESTS_RUN + 1))
    printf '  %sPASS%s %s\n' "$C_GREEN" "$C_OFF" "$1"
}

function fail() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf '  %sFAIL%s %s\n' "$C_RED" "$C_OFF" "$1"
    if [ -n "${2:-}" ]; then
        printf '       %s%s%s\n' "$C_DIM" "$2" "$C_OFF"
    fi
}

# assert_ok <description> <command...>
function assert_ok() {
    local desc="$1"; shift
    local out
    if out=$("$@" 2>&1); then
        pass "$desc"
    else
        fail "$desc" "exit $? from: $* :: ${out:0:400}"
    fi
}

# assert_fails <description> <command...>
function assert_fails() {
    local desc="$1"; shift
    local out
    if out=$("$@" 2>&1); then
        fail "$desc" "expected failure but it succeeded: $*"
    else
        pass "$desc"
    fi
}

# assert_eq <description> <expected> <actual>
function assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        pass "$desc"
    else
        fail "$desc" "expected [$expected] got [$actual]"
    fi
}

# assert_symlink <path> [target-substring]
function assert_symlink() {
    local path="$1" want="${2:-}"
    if [ ! -L "$path" ]; then
        fail "$path is a symlink" "$( [ -e "$path" ] && echo 'exists but is a regular file/dir' || echo 'does not exist' )"
        return
    fi
    local target
    target=$(readlink "$path")
    if [ -n "$want" ] && [[ "$target" != *"$want"* ]]; then
        fail "$path -> *$want*" "points at $target"
        return
    fi
    if [ ! -e "$path" ]; then
        fail "$path is a live symlink" "dangling -> $target"
        return
    fi
    pass "$path -> $target"
}

# assert_exists <path>
function assert_exists() {
    if [ -e "$1" ]; then pass "$1 exists"; else fail "$1 exists" "missing"; fi
}

# assert_missing <path>
function assert_missing() {
    if [ ! -e "$1" ]; then pass "$1 absent"; else fail "$1 absent" "unexpectedly present"; fi
}

# assert_grep <description> <pattern> <file>
function assert_grep() {
    local desc="$1" pattern="$2" file="$3"
    if [ ! -f "$file" ]; then
        fail "$desc" "no such file: $file"
    elif grep -qE "$pattern" "$file"; then
        pass "$desc"
    else
        fail "$desc" "pattern /$pattern/ not found in $file"
    fi
}

# assert_no_grep <description> <pattern> <file>
function assert_no_grep() {
    local desc="$1" pattern="$2" file="$3"
    if [ -f "$file" ] && grep -qE "$pattern" "$file"; then
        fail "$desc" "pattern /$pattern/ unexpectedly found in $file"
    else
        pass "$desc"
    fi
}

function summary() {
    printf '\n%s%d run, %d failed%s\n' "$C_BOLD" "$TESTS_RUN" "$TESTS_FAILED" "$C_OFF"
    [ "$TESTS_FAILED" -eq 0 ]
}

# assert_links_into <path> <substring-of-resolved-target>
# Tolerates stow "folding": the link may be on a parent directory.
function assert_links_into() {
    local path="$1" want="$2" real
    if [ ! -e "$path" ]; then
        fail "$path links into *$want*" "path does not exist"
        return
    fi
    real=$(readlink -f "$path")
    if [[ "$real" == *"$want"* ]]; then
        pass "$path => $real"
    else
        fail "$path links into *$want*" "resolves to $real"
    fi
}

# assert_log_has <pattern>  -- greps $STUB_LOG
function assert_log_has() {
    assert_grep "stub log records: $1" "$1" "${STUB_LOG:-/tmp/stub.log}"
}

# assert_log_missing <pattern>
function assert_log_missing() {
    assert_no_grep "stub log does NOT record: $1" "$1" "${STUB_LOG:-/tmp/stub.log}"
}
