#!/usr/bin/env bash
# Print the tail of a subagent pane (bounded, for cheap diagnosis).
# Usage: aos-peek.sh <window> [lines=40]
#   <window> may be a bare maestro window name (aos-xyz), resolved through
#   this home's state/<id>.meta, or explicit session:window.
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AOS_ROOT="${AOS_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
AOS_HOME="${AOS_HOME:-${AOS_ROOT_OVERRIDE:-$AOS_ROOT}}"
STATE="${AOS_STATE_OVERRIDE:-$AOS_HOME/state}"

"$SCRIPT_DIR/aos-guard.sh" || true

resolve() {
  case "$1" in
    *:*) echo "$1" ;;
    aos-*)
      meta="$STATE/${1#aos-}.meta"
      if [ ! -f "$meta" ]; then
        echo "error: no metadata for $1 in $STATE; pass session:window to target a window outside this maestro home" >&2
        exit 1
      fi
      window=$(grep '^window=' "$meta" 2>/dev/null | tail -1 | cut -d= -f2- || true)
      [ -n "$window" ] || { echo "error: no window recorded in $meta" >&2; exit 1; }
      echo "$window"
      ;;
    *) tmux list-windows -a -F '#{session_name}:#{window_name}' | grep -m1 ":$1\$" \
         || { echo "error: no window named $1" >&2; exit 1; } ;;
  esac
}

T=$(resolve "$1")
N=${2:-40}
tmux capture-pane -p -t "$T" -S -"$N"
