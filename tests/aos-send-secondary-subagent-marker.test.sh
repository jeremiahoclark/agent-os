#!/usr/bin/env bash
# aos-send from-maestro marker for secondary_subagent targets.
#
# A secondary_subagent is itself a maestro, so a request relayed to it lands in its own
# chat - which the main maestro never reads (the only channel back is the terse
# status file). aos-send therefore prepends a from-maestro marker
# (bin/aos-marker-lib.sh) when, and only when, the resolved target is a bare
# `aos-<id>` whose meta records kind=secondary_subagent, so the secondary_subagent can recognize
# the request and route its reply via the status path. These tests pin that
# behavior hermetically (stubbed tmux, no real agent):
#   1. A send to a kind=secondary_subagent target prepends the marker to the literal text.
#   2. A send to a subagent (kind=ship) target sends the bare text, no marker.
#   3. An explicit session:window target (no meta) is never marked.
#   4. The --key path never carries the marker.
#   5. The marker is exactly the label "[aos-from-maestro]" + ASCII 0x1f, and the
#      fm_message_from_maestro detector keys on that untypable sequence.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=bin/aos-marker-lib.sh
. "$ROOT/bin/aos-marker-lib.sh"

SEND="$ROOT/bin/aos-send.sh"

TMP_ROOT=$(fm_test_tmproot aos-send-marker)

# A fake tmux that (a) records the literal text of every `send-keys -l` to
# AOS_SEND_LOG and (b) lets aos-send's submit path reach a clean "empty" verdict.
# display-message yields a numeric cursor_y; capture-pane returns an empty
# bordered composer so fm_tmux_composer_state reads "empty" (submit landed) on the
# first Enter. Only the literal (-l) text is logged; Enter retries and --key sends
# are not, so the log holds exactly what was typed into the composer.
make_stubs() {  # <dir> -> echoes fakebin dir
  local dir=$1 fb="$1/fakebin"
  mkdir -p "$fb"
  cat > "$fb/tmux" <<'SH'
#!/usr/bin/env bash
set -u
case "${1:-}" in
  send-keys)
    shift
    literal=0
    while [ $# -gt 0 ]; do
      case "$1" in
        -t) shift 2 ;;
        -l) literal=1; shift ;;
        *) break ;;
      esac
    done
    if [ "$literal" = 1 ]; then
      printf '%s' "${1:-}" >> "$AOS_SEND_LOG"
    fi
    exit 0 ;;
  display-message)
    for a in "$@"; do case "$a" in *cursor_y*) printf '0\n'; exit 0 ;; esac; done
    printf 'fakepane\n'; exit 0 ;;
  capture-pane) printf '\xe2\x94\x82 \xe2\x94\x82\n'; exit 0 ;;
  list-windows) exit 0 ;;
esac
exit 0
SH
  chmod +x "$fb/tmux"
  cat > "$fb/sleep" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$fb/sleep"
  printf '%s\n' "$fb"
}

# run_send <fakebin> <home> <send-log> -- <aos-send args...>
# Runs aos-send.sh with the stubs on PATH against the given home (which holds
# state/<id>.meta). AOS_ROOT_OVERRIDE points at the same non-repo home so
# aos-guard's tangle check stays silent; guard noise goes to stderr (discarded).
# AOS_SEND_SETTLE=0 keeps the run fast. Truncates the log first; returns aos-send's
# exit code.
run_send() {
  local fb=$1 home=$2 log=$3; shift 3
  : > "$log"
  env PATH="$fb:$PATH" \
    AOS_ROOT_OVERRIDE="$home" AOS_HOME="$home" AOS_SEND_LOG="$log" AOS_SEND_SETTLE=0 \
    "$SEND" "$@" 2>/dev/null
}

# setup_home <name> -> echoes a fresh home dir with an empty state/.
setup_home() {
  local home="$TMP_ROOT/$1-$RANDOM"
  mkdir -p "$home/state"
  printf '%s\n' "$home"
}

test_secondary_subagent_target_is_marked() {
  local dir fb log home rc got
  dir="$TMP_ROOT/sm"; mkdir -p "$dir"
  fb=$(make_stubs "$dir"); log="$dir/send.log"
  home=$(setup_home sm)
  aos_write_secondary_subagent_meta "$home/state/domain.meta" "$home" "sess:aos-domain"
  run_send "$fb" "$home" "$log" "aos-domain" "audit the build"; rc=$?
  expect_code 0 "$rc" "send to a secondary_subagent target should succeed"
  got=$(cat "$log")
  case "$got" in
    "$AOS_FROMFIRST_MARK"audit\ the\ build) : ;;
    *) fail "secondary_subagent send: literal text should be marker+text"$'\n'"--- bytes ---"$'\n'"$(printf '%s' "$got" | od -An -c)" ;;
  esac
  pass "aos-send: a kind=secondary_subagent target gets the from-maestro marker prepended"
}

test_subagent_target_is_not_marked() {
  local dir fb log home rc got
  dir="$TMP_ROOT/crew"; mkdir -p "$dir"
  fb=$(make_stubs "$dir"); log="$dir/send.log"
  home=$(setup_home crew)
  aos_write_meta "$home/state/build.meta" \
    "window=sess:aos-build" "worktree=$home/wt" "project=$home/p" \
    "harness=echo" "kind=ship" "mode=no-mistakes" "yolo=off"
  run_send "$fb" "$home" "$log" "aos-build" "fix the test"; rc=$?
  expect_code 0 "$rc" "send to a subagent target should succeed"
  got=$(cat "$log")
  [ "$got" = "fix the test" ] \
    || fail "subagent send: expected bare text, got marker or other"$'\n'"--- bytes ---"$'\n'"$(printf '%s' "$got" | od -An -c)"
  pass "aos-send: a kind=ship (subagent) target is sent unmarked"
}

test_explicit_window_is_not_marked() {
  local dir fb log home rc got
  dir="$TMP_ROOT/explicit"; mkdir -p "$dir"
  fb=$(make_stubs "$dir"); log="$dir/send.log"
  home=$(setup_home explicit)
  # No meta lookup happens for an explicit session:window target, so even with a
  # same-named secondary_subagent meta present it must stay unmarked (escape hatch).
  aos_write_secondary_subagent_meta "$home/state/win.meta" "$home" "other:win"
  run_send "$fb" "$home" "$log" "other:win" "ping"; rc=$?
  expect_code 0 "$rc" "send to an explicit window should succeed"
  got=$(cat "$log")
  [ "$got" = "ping" ] \
    || fail "explicit session:window send: expected bare text, got marker"$'\n'"--- bytes ---"$'\n'"$(printf '%s' "$got" | od -An -c)"
  pass "aos-send: an explicit session:window target is never marked"
}

test_key_path_is_not_marked() {
  local dir fb log home rc
  dir="$TMP_ROOT/key"; mkdir -p "$dir"
  fb=$(make_stubs "$dir"); log="$dir/send.log"
  home=$(setup_home key)
  aos_write_secondary_subagent_meta "$home/state/domain.meta" "$home" "sess:aos-domain"
  run_send "$fb" "$home" "$log" "aos-domain" --key Escape; rc=$?
  expect_code 0 "$rc" "--key send to a secondary_subagent should succeed"
  [ ! -s "$log" ] \
    || fail "--key path logged a literal send (marker leaked into a keypress)"$'\n'"--- bytes ---"$'\n'"$(od -An -c "$log")"
  pass "aos-send: the --key path carries no marker (no literal text is typed)"
}

test_marker_is_label_plus_unit_separator() {
  local us hex
  us=$(printf '\037')
  [ "$AOS_FROMFIRST_MARK" = "[aos-from-maestro]$us" ] \
    || fail "marker is not the expected label + 0x1f sequence"$'\n'"--- bytes ---"$'\n'"$(printf '%s' "$AOS_FROMFIRST_MARK" | od -An -c)"
  # The last byte must be ASCII unit separator 0x1f, the untypable guarantee.
  hex=$(printf '%s' "$AOS_FROMFIRST_MARK" | od -An -tx1 | tr -d ' \n')
  case "$hex" in
    *1f) : ;;
    *) fail "marker does not end in a 0x1f byte; bytes were: $hex" ;;
  esac
  # The detector keys on that exact untypable sequence.
  fm_message_from_maestro "${AOS_FROMFIRST_MARK}do the work" \
    || fail "detector should recognize a marked message"
  fm_message_from_maestro "do the work" \
    && fail "detector must reject an unmarked message"
  # The bare label without the separator (the typable part) is NOT a match.
  fm_message_from_maestro "[aos-from-maestro]do the work" \
    && fail "detector must reject the label without the 0x1f separator"
  pass "aos-send: the marker is exactly '[aos-from-maestro]' + ASCII 0x1f, detector keys on it"
}

test_secondary_subagent_target_is_marked
test_subagent_target_is_not_marked
test_explicit_window_is_not_marked
test_key_path_is_not_marked
test_marker_is_label_plus_unit_separator
