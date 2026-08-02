---
name: brief
description: Morning email/action brief from Bliss. Use when the owner invokes /brief, asks for the morning brief, "what's outstanding", or "what do I need to do today". Syncs Gmail/Calendar via the bliss CLI, triages with the Eisenhower Matrix, presents max 10 actions split into owner-must-do vs agent-can-do, proactively offers to execute the agent-side items, and seeds today's daily note with a tracked action list for the evening /review.
user-invocable: true
---

# brief

Morning brief. The whole point is proactive sifting: figure out what *the
owner* actually has to do, and claim everything the agent can do on his
behalf. Never present a raw email list.

## Data source

The `bliss` CLI (symlinked at `~/.local/bin/bliss`, repo `~/dev/bliss`). All
commands print JSON. Relevant here:

- `bliss sync` — pull latest Gmail + Calendar (all 5 accounts)
- `bliss triage` — classify new mail into Eisenhower quadrants (LLM; can take
  a couple of minutes — run in background/tmux if slow)
- `bliss actions --quadrant <q> [--limit N]` — open triage items
- `bliss calendar upcoming --limit 15` — today's meetings
- `bliss bulk-archive` — dry-run list of archivable junk

## Steps

1. `bliss sync`, then `bliss triage`, then pull `bliss actions` for the three
   working quadrants and `bliss calendar upcoming`.
2. Build the brief — **hard cap 10 actions**, ordered by the Eisenhower rule:
   - `urgent_important` → **Owner: do ASAP.** These lead the brief.
   - `important` → **Schedule.** Don't ask the owner to act now; mark them
     as schedule candidates and offer to run /schedule.
   - `urgent` (not important) → **Agent handles.** Don't put these on the
     owner unless they truly need his judgment.
   - `neither` → never in the brief. Report only the count and hand the
     batch to mimo (step 5).
   Dedupe by thread/sender; prefer items with a concrete `ask`. If more than
   10 qualify, keep the most consequential and say how many were held back.
3. **Claim agent-side work.** For every item the agent can do, say so
   explicitly in the brief and offer to do it now in one batch:
   - simple replies and acknowledgments (draft, show, send only on approval)
   - follow-ups on threads waiting on the other side
   - calendar invites / holds via
     `bliss calendar create --account jeremiahoclark@gmail.com --summary ... --start ... --end ... [--attendees a,b --send-updates all]`
     (work meetings go on the account that owns the relationship instead).
   Anything that sends email or invites to another human needs explicit
   owner approval first; drafts and self-only calendar holds don't.
4. **Seed the daily note.** In today's note
   (`01 - Daily Notes/<MM-YYYY>/<MM-DD-YY>.md`, create from the template if
   missing), append:

   ```markdown
   ## Brief — <h:mm A> EDT

   ### Owner actions
   - [ ] <action> (est: <X>m) <!-- triage:<triage_id> -->

   ### Agent actions
   - [ ] <action> — agent <!-- triage:<triage_id> -->
   ```

   Estimates come from the agent, calibrated by
   `01 - Daily Notes/Time Performance Log.md` if it has history (apply the
   owner's historical estimate-vs-actual multiplier). The `triage:` comments
   let /review reconcile without guessing.
5. **Junk goes to mimo, never to this agent.** If `bliss bulk-archive`
   (dry-run) shows eligible mail, delegate:

   ```
   mimo run "You are processing junk email for Jeremiah. Run 'bliss bulk-archive' (dry-run), review the sender groups, then run 'bliss bulk-archive --execute' excluding via --exclude-senders any sender that looks like a real human or a receipt/legal/financial record. Report counts archived and excluded."
   ```

   Run it in background/tmux; report the outcome when it finishes. Do not
   read, summarize, or otherwise touch neither-quadrant email yourself.
6. Deliver the brief in chat: today's meetings first (one line each), then
   owner actions, then what the agent is claiming, then the mimo/junk
   count. Mark items done as they complete with
   `bliss mark --status done --ids <triage_id>...` and check them off in the
   daily note.
