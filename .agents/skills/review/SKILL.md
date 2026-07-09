---
name: review
description: End-of-day review of the morning brief and schedule. Use when the captain invokes /review, says "let's review the day", "wrapping up", or "end of day". Builds an interactive lavish doc to reconcile brief items (done / not / carried), capture non-coding work done, collect actual time spent vs estimates and schedule adherence, then updates the daily note and appends to the Time Performance Log.
user-invocable: true
---

# review

Evening close-out. Two outputs: an honest record of the day in the daily
note, and calibration data (estimated vs actual time) that makes tomorrow's
estimates better.

## Steps

1. Gather state:
   - Today's daily note `## Brief` section (checkboxes + `triage:` ids +
     estimates).
   - `bliss actions` for anything still open, `bliss calendar upcoming` /
     today's events for the planned schedule.
   - Any work sessions logged in the daily note since the brief.
2. Build an interactive review doc with lavish (load the `lavish` skill; use
   the **input** playbook, plus **table**). Put it in
   `~/dev/_agentOS/.lavish/daily-review-<MM-DD-YY>.html`. The doc must let
   the captain, per brief item: mark done / not done / carry to tomorrow /
   drop; enter **actual minutes** next to the shown estimate; and at the
   bottom: free-entry rows to add things done outside coding work, a
   schedule-adherence question (which planned blocks actually happened), and
   an overall day rating. Then `lavish-axi poll` (background) and wait for
   feedback.
3. On feedback, write results back:
   - **Daily note:** check off completed items; append a `## Review — <h:mm A> EDT`
     section: what got done (including the captain's added non-coding items),
     what carries to tomorrow, schedule adherence (X of Y planned blocks
     held, with a one-line why for misses), decisions worth remembering. Add
     one Index line for the headline outcome.
   - **Time Performance Log** (`01 - Daily Notes/Time Performance Log.md`):
     append one table row per item that has both an estimate and an actual.
     Update the running multiplier line at the top per the file's own
     instructions.
   - **Bliss:** `bliss mark --status done --ids ...` for completed triage
     items; leave carried items pending.
4. Close in chat with a 3-line summary: done vs planned, estimate accuracy
   today (e.g. "estimates ran 1.4× short"), and the top carry-over for
   tomorrow. Offer to pre-seed tomorrow's /schedule with the carry-overs.

Never rewrite or reorganize `TODO.md` — flag apparent drift in chat instead.
