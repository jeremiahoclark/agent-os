---
name: schedule
description: Plan the day onto the owner's personal Google Calendar. Use when the owner invokes /schedule, asks to "schedule my day", "block time", or "plan today/tomorrow". Collects todos (brief schedule-candidates, TODO.md, owner input), proposes priorities and calibrated time estimates, aligns via an interactive lavish doc, then creates the agreed blocks with bliss calendar create.
user-invocable: true
---

# schedule

Turn the day's todos into concrete calendar blocks. Alignment happens in a
lavish doc *before* anything touches the calendar.

## Steps

1. Collect candidates:
   - Schedule-quadrant items from the brief / `bliss actions --quadrant important --quadrant urgent_important`
   - `TODO.md` (read-only — never edit it)
   - Carry-overs from yesterday's `## Review`
   - Anything the owner names when invoking
   - **Unanswered texts:** `bliss imessage unanswered --days 7` (laptop-only;
     reads the local Messages DB, newest message per thread only, never
     sends). For each thread that looks like a real person waiting
     (`ever_replied: true` is the strong signal; skip obvious
     marketing/OTP/reply-STOP noise), either nudge the owner to respond --
     he answers his own texts -- or, if the message contains a task or
     commitment, add it as a schedule candidate. Also cross-check
     appointment-reminder texts against the calendar for conflicts.
2. Get the real free space: `bliss sync` if stale, then
   `bliss calendar upcoming` for existing meetings on the target day. Blocks
   must fit around them.
3. Estimate and prioritize. Use the Eisenhower rule (urgent+important
   earliest), and calibrate every estimate with the multiplier in
   `01 - Daily Notes/Time Performance Log.md` — if history says estimates run
   1.4× short, pad by 1.4×. Prefer ≤90-minute focus blocks with breathing
   room between; don't schedule more than ~70% of available hours.
4. Align via lavish (load the `lavish` skill; **input** + **table**
   playbooks): proposed blocks on a timeline with priority, estimate, and
   rationale; per-block controls to accept / resize / move / drop; a rank
   control for priorities. `lavish-axi poll` in background and wait.
5. On agreement, create each block on the personal calendar:

   ```
   bliss calendar create --account jeremiahoclark@gmail.com \
     --summary "<block name>" --start <ISO> --end <ISO> \
     --description "<what done looks like>"
   ```

   Self-only holds need no approval. Anything with `--attendees` (a real
   invite to another person) needs explicit owner sign-off per event, and
   `--send-updates all` so invites actually send. Work-domain meetings go on
   the matching work account instead of the personal one.
6. Report the created blocks (times + event links) in chat and note the plan
   in today's daily note under the Brief section (`### Schedule` list). The
   evening /review will measure adherence against exactly this list.
