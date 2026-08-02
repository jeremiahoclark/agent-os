#!/usr/bin/env bash
# Self-update a running maestro and its secondary_subagents to the latest origin.
#
# Mechanical half of the /update-agentos skill. Fast-forwards the running
# maestro repo's default branch from origin, then fast-forwards every
# registered secondary_subagent home (each a treehouse worktree of this same repo, or
# a standalone clone) the same way. FAST-FORWARD ONLY, exactly like
# aos-fleet-sync.sh: never force, never create a merge commit, never stash;
# advance a target only when it is a clean fast-forward, otherwise skip and
# report. A tracked-files fast-forward never touches the gitignored operational
# dirs (data/, state/, config/, projects/, .no-mistakes/), so a secondary_subagent's
# in-flight work is never disrupted. Worktrees of this repo share one object
# store, so a single fetch refreshes them all; standalone-clone homes are
# fetched on their own. Secondary_subagent homes are leased at a detached HEAD on the
# default branch, so a fast-forward there advances HEAD only and never touches
# any other worktree's checkout or the shared `main` branch.
#
# The fast-forward mechanics live in bin/aos-ff-lib.sh (base_mode "origin" here);
# the same library drives the local-HEAD secondary_subagent sync used by aos-spawn.sh and
# aos-bootstrap.sh, so there is one ff implementation, not several.
#
# It does NOT re-read AGENTS.md or nudge secondary_subagents itself - those are LLM /
# tmux actions the skill performs. The script's job is the safe git mechanics
# plus a parseable summary telling the caller what to do next:
#   - one status line per target (updated/already current/skipped)
#   - reread-maestro: yes|no    (did the running maestro's instructions change)
#   - nudge_secondary_subagents: <window-targets...>|none   (updated live secondary_subagents to nudge)
#
# Usage: aos-update.sh [--help]
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AOS_ROOT="${AOS_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
AOS_HOME="${AOS_HOME:-${AOS_ROOT_OVERRIDE:-$AOS_ROOT}}"
STATE="${AOS_STATE_OVERRIDE:-$AOS_HOME/state}"
SECONDARY_SUBAGENTS_MD="$AOS_HOME/data/secondary_subagents.md"
# shellcheck source=bin/aos-ff-lib.sh
. "$SCRIPT_DIR/aos-ff-lib.sh"

"$SCRIPT_DIR/aos-guard.sh" || true

usage() { echo "usage: aos-update.sh [--help]" >&2; }

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi
[ $# -eq 0 ] || { usage; exit 1; }

# --- main maestro repo ---------------------------------------------------

reread_maestro="no"
ff_target "$AOS_ROOT" "maestro" origin no no
if [ "$FF_STATUS" = "updated" ] && [ -n "$FF_INSTR" ]; then
  reread_maestro="yes"
fi

# --- secondary_subagents -----------------------------------------------------------
# An updated live secondary_subagent is nudged whenever it advanced (nudge_requires_instr
# is "no" here): /update-agentos's nudge is a gentle re-read steer, kept on the
# same condition it has always used.

FF_NUDGE_WINDOWS=""
FF_SEEN_HOMES=""

# Live direct reports first: state/<id>.meta with kind=secondary_subagent carries the
# authoritative home= path.
sweep_live_secondary_subagent_metas "$STATE" origin no

# Registry backstop: a secondary_subagent registered in data/secondary_subagents.md but without
# a live meta (e.g. between restarts) is still its persistent on-disk home.
if [ -f "$SECONDARY_SUBAGENTS_MD" ]; then
  while IFS= read -r line; do
    case "$line" in
      "- "*) ;;
      *) continue ;;
    esac
    id=$(printf '%s\n' "$line" | sed -n 's/^- \([^ ][^ ]*\) - .*/\1/p')
    home=$(printf '%s\n' "$line" | sed -n 's/.*(home:[[:space:]]*\([^;]*\);.*/\1/p' | sed 's/[[:space:]]*$//')
    process_secondary_subagent "$id" "$home" "" origin no
  done < "$SECONDARY_SUBAGENTS_MD"
fi

# --- caller action summary -------------------------------------------------

echo "reread-maestro: $reread_maestro"
echo "nudge_secondary_subagents:${FF_NUDGE_WINDOWS:- none}"
