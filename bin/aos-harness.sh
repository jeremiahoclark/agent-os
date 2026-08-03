#!/usr/bin/env bash
# Detect the agent harness this process tree runs on.
# Usage: aos-harness.sh         print own harness: claude|codex|opencode|pi|unknown
#        aos-harness.sh subagent  print the effective subagent harness
#                                (config/subagent-harness; "default" resolves to own)
#        aos-harness.sh crew      legacy alias for subagent
# Detection layers: verified environment markers first, then process ancestry.
# Record each newly verified env marker here.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AOS_ROOT="${AOS_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
AOS_HOME="${AOS_HOME:-${AOS_ROOT_OVERRIDE:-$AOS_ROOT}}"
CONFIG="${AOS_CONFIG_OVERRIDE:-$AOS_HOME/config}"

detect_own() {
  # Layer 1: environment markers for verified harnesses.
  [ "${CLAUDECODE:-}" = "1" ] && { echo claude; return; }
  [ "${PI_CODING_AGENT:-}" = "true" ] && { echo pi; return; }
  # Layer 2: walk the parent chain and match the command name.
  local pid=$$ comm args
  for _ in 1 2 3 4 5 6 7 8; do
    comm=$(ps -o comm= -p "$pid" 2>/dev/null) || break
    case "$(basename "$comm")" in
      *claude*) echo claude; return ;;
      *codex*) echo codex; return ;;
      *opencode*) echo opencode; return ;;
      pi) echo pi; return ;;
      node*|python*)
        # Bare interpreter: match the harness name in its script path.
        args=$(ps -o args= -p "$pid" 2>/dev/null)
        case "$args" in
          *claude*) echo claude; return ;;
          *codex*) echo codex; return ;;
          *opencode*) echo opencode; return ;;
          *" pi "*|*/pi) echo pi; return ;;
        esac ;;
    esac
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    if [ -z "$pid" ] || [ "$pid" -le 1 ]; then
      break
    fi
  done
  echo unknown
}

if [ "${1:-}" = "subagent" ] || [ "${1:-}" = "crew" ]; then
  harness=
  [ -f "$CONFIG/subagent-harness" ] && harness=$(tr -d '[:space:]' < "$CONFIG/subagent-harness" || true)
  if [ -z "$harness" ] || [ "$harness" = "default" ]; then detect_own; else echo "$harness"; fi
else
  detect_own
fi
