#!/usr/bin/env bash
# Link a spawned task to the X mention that triggered it, so maestro can post
# ONE completion follow-up reply when the task lands (within a 24h window).
#
# Usage: aos-x-link.sh <task-id> <request_id>
#
# Records two lines in state/<task-id>.meta (replacing any prior link, preserving
# every other meta line):
#   x_request=<request_id>     the relay-issued id the follow-up posts against
#   x_request_ts=<epoch>       link time, for the 24h follow-up window
#
# This is a separate step the aosx-respond skill runs AFTER aos-spawn.sh, so it
# never changes aos-spawn's interface. The follow-up itself - detection, the
# window check, the post, and clearing the link - is owned by aos-x-followup.sh on
# the task's terminal-completion wake. The meta read/write lives in aos-x-lib.sh.
#
# Both ids are relay/maestro slugs that compose a filename, so they are guarded
# against path traversal even though they come from trusted callers.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AOS_ROOT="${AOS_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
AOS_HOME="${AOS_HOME:-${AOS_ROOT_OVERRIDE:-$AOS_ROOT}}"
STATE="${AOS_STATE_OVERRIDE:-$AOS_HOME/state}"
# shellcheck source=bin/aos-x-lib.sh
. "$SCRIPT_DIR/aos-x-lib.sh"

ID=${1:-}
RID=${2:-}
if [ -z "$ID" ] || [ -z "$RID" ]; then
  echo "usage: aos-x-link.sh <task-id> <request_id>" >&2
  exit 2
fi

# task-id composes a path (state/<id>.meta); request_id composes a path elsewhere
# (the inbox/outbox record). Reject anything outside a safe slug for both.
case "$ID" in
  ''|.*|*[!A-Za-z0-9._-]*) echo "aos-x-link: unsafe task id: $ID" >&2; exit 2 ;;
esac
case "$RID" in
  ''|.*|*[!A-Za-z0-9._-]*) echo "aos-x-link: unsafe request_id: $RID" >&2; exit 2 ;;
esac

META="$STATE/$ID.meta"
if [ ! -f "$META" ]; then
  echo "aos-x-link: no such task: state/$ID.meta" >&2
  exit 1
fi

# AOSX_NOW_OVERRIDE keeps tests deterministic; production uses the wall clock.
NOW=${AOSX_NOW_OVERRIDE:-$(date +%s)}
case "$NOW" in
  ''|*[!0-9]*) echo "aos-x-link: could not read the current time" >&2; exit 1 ;;
esac

if ! fmx_meta_link_set "$META" "$RID" "$NOW"; then
  echo "aos-x-link: failed to record the link in state/$ID.meta" >&2
  exit 1
fi

printf 'linked %s to X request %s\n' "$ID" "$RID"
