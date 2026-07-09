---
name: schedule
description: Plan the day onto the captain's personal Google Calendar. Use when the captain invokes /schedule, asks to "schedule my day", "block time", or "plan today/tomorrow". Collects todos (brief schedule-candidates, TODO.md, captain input), proposes priorities and calibrated time estimates, aligns via an interactive lavish doc, then creates the agreed blocks with bliss calendar create.
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
   - Anything the captain names when invoking
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
   invite to another person) needs explicit captain sign-off per event, and
   `--send-updates all` so invites actually send. Work-domain meetings go on
   the matching work account instead of the personal one.
6. Report the created blocks (times + event links) in chat and note the plan
   in today's daily note under the Brief section (`### Schedule` list). The
   evening /review will measure adherence against exactly this list.
