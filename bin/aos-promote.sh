#!/usr/bin/env bash
# Promote a scout task to a ship task in place: the subagent keeps its window,
# worktree, and loaded context; only the contract changes. Flips kind= to ship in
# state/<task-id>.meta so aos-teardown.sh applies the full ship-task teardown protection
# again. After promoting, send the subagent its ship instructions via aos-send.sh
# (inventory scratch state, reset to a clean default-branch base, carry over only
# intended fix changes, create branch fm/<task-id>, implement, then report done
# according to the project's delivery mode).
# Usage: aos-promote.sh <task-id>
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AOS_ROOT="${AOS_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
AOS_HOME="${AOS_HOME:-${AOS_ROOT_OVERRIDE:-$AOS_ROOT}}"
STATE="${AOS_STATE_OVERRIDE:-$AOS_HOME/state}"
"$AOS_ROOT/bin/aos-guard.sh" || true
ID=$1
META="$STATE/$ID.meta"
[ -f "$META" ] || { echo "error: no meta for task $ID at $META" >&2; exit 1; }
grep -qx 'kind=scout' "$META" || { echo "error: task $ID is not a scout task (kind=scout not in meta)" >&2; exit 1; }

TMP="$META.tmp"
grep -v '^kind=' "$META" > "$TMP"
echo "kind=ship" >> "$TMP"
mv "$TMP" "$META"

echo "promoted $ID to ship (teardown protection restored)"
echo "next: bin/aos-send.sh aos-$ID '<ship instructions: review scratch state with git status and git log; reset to a clean default-branch base; carry over only intended fix changes; create branch fm/$ID; implement; report done>'"
