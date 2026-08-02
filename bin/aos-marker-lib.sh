#!/usr/bin/env bash
# aos-marker-lib.sh - the from-maestro request marker.
#
# When the MAIN maestro relays a work request to one of its secondary_subagents,
# bin/aos-send.sh prepends this marker to the message text. A secondary_subagent is itself
# a maestro running in its own home, so without a marker it treats every
# incoming aos-send/tmux line as if its owner typed it and answers
# CONVERSATIONALLY in its own chat. But the main maestro never reads a
# secondary_subagent's chat: the only main<-secondary_subagent wakeup channel is the status file
# (charter escalation), optionally pointing to a doc for detail. A detailed
# chat-only reply therefore strands, unseen.
#
# The marker lets the secondary_subagent tell its supervisor's request apart from a
# message the owner typed directly into its pane:
#
#   - marked   -> a from-maestro request. Do the work, then respond via the
#                 STATUS/ESCALATION path (a status line for a terse result, or a
#                 doc plus a status pointer - the scout-report pattern - for a
#                 detailed one) so it surfaces to the main maestro via the
#                 watcher signal. It MUST NOT respond only in chat.
#   - unmarked -> the owner typing directly. Stay conversational, exactly as
#                 before: authoritative owner intervention.
#
# This contract lives in the generated secondary_subagent charter (bin/aos-brief.sh) so it
# travels with the live secondary_subagent, and is summarized in AGENTS.md.
#
# Distinct from the afk daemon marker, on purpose.
# The away-mode daemon (bin/aos-supervise-daemon.sh) marks its daemon->maestro
# escalations with a BARE leading unit separator (AOS_INJECT_MARK, ASCII 0x1f).
# This from-maestro marker mirrors that CONCEPT - it reuses the ASCII unit
# separator (0x1f), which is untypable on a normal keyboard, as the "a human can
# never forge this" guarantee - but it is a DISTINCT sequence: a human-readable
# label FOLLOWED by the separator, never a bare leading 0x1f. The afk contract
# keys on a LEADING 0x1f, which this marker never has, so the two cannot
# conflate: a secondary_subagent's own afk machinery never mistakes a from-maestro
# request for an internal daemon escalation, and vice versa. The visible label is
# also what the secondary_subagent's LLM actually reads in its pane, since the separator
# byte itself is invisible.
#
# Sourced by bin/aos-send.sh, bin/aos-brief.sh, and the tests. No side effects on
# source. set -u / set -e safe.

# The label field: human-readable, greppable, and distinctive enough that the
# owner would not type it by hand. This is the part the secondary_subagent's LLM reads.
AOS_FROMFIRST_LABEL='[aos-from-maestro]'

# The full marker aos-send prepends to a from-maestro request: the label, then
# the ASCII unit separator (0x1f) as the untypable field separator. The request
# text follows the separator.
AOS_FROMFIRST_MARK="${AOS_FROMFIRST_LABEL}"$'\x1f'

# fm_message_from_maestro: 0 (true) if <message> carries the from-maestro
# marker - it begins with the label immediately followed by the unit separator -
# and 1 otherwise. The unit separator is untypable, so a owner-typed message,
# even one that happens to start with the label text alone, is never matched.
fm_message_from_maestro() {  # <message>
  case "$1" in
    "$AOS_FROMFIRST_MARK"*) return 0 ;;
  esac
  return 1
}
