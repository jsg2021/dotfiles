# Running install twice must be safe and leave the same result.
source "$DOT/tests/container/scenarios/_common.sh"

run_install
first=$INSTALL_STATUS
run_install
second=$INSTALL_STATUS
[ "$second" -eq 0 ] || show_install_log

suite "second run"
assert_eq "first run exits 0"  "0" "$first"
assert_eq "second run exits 0" "0" "$second"

suite "links survive a re-run"
assert_core_links
assert_ignored_not_linked
assert_every_config_linked
assert_no_dangling_links

suite "no duplicate stash piled up"
assert_ok "at most one stash entry" \
    bash -c "test \$(cd '$DOT' && git stash list | wc -l) -le 1"

suite "repo still clean"
assert_ok "git status clean" \
    bash -c "cd '$DOT' && test -z \"\$(git status --porcelain)\""
