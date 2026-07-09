---
name: bulk-archive
description: Bulk-archive non-important non-urgent email via mimo. Use when the captain invokes /bulk-archive, says "clear out my inbox", "archive the junk", or asks about inbox zero. Shows the bliss dry-run summary, then delegates execution to the mimo coding agent — this agent never processes neither-quadrant email itself.
user-invocable: true
---

# bulk-archive

Clear `neither`-quadrant mail (not urgent, not important → archive). Standing
rule: **this agent never reads or processes junk-tier email.** The expensive
model's job ends at counts and delegation; mimo does the actual processing.

## What the CLI already guarantees

`bliss bulk-archive` only ever targets triage quadrant `neither` with
`needs_reply = 0`, and additionally excludes: starred/IMPORTANT-labeled mail,
calendar invites, threads the captain has replied to, senders marked
never-archive, and anything under 2 days old. Archiving removes the INBOX
label — nothing is deleted from Gmail.

## Steps

1. `bliss bulk-archive` (dry-run). Report only the top-line numbers to the
   captain: total eligible, number of sender groups, top 5 senders by count.
   Do not summarize message contents.
2. Delegate execution to mimo, in background/tmux:

   ```
   mimo run "You are processing junk email for Jeremiah. Run 'bliss bulk-archive' (dry-run) and review the sender groups. Then run 'bliss bulk-archive --execute', using --exclude-senders for any sender that looks like a real human being, or a receipt, invoice, legal, tax, or account-security record. Archiving only removes mail from the inbox; nothing is deleted. Report: total archived, senders excluded and why."
   ```

3. Relay mimo's report. If the captain says some sender should never be
   archived again, record it:
   `sqlite3 ~/dev/bliss/data/bliss.sqlite3 "update senders set never_archive=1 where email='<sender>'"`
   (or reject via the bliss web UI proposals screen).
4. If we're being too aggressive (captain flags a miss), note the sender as
   never-archive and mention the miss in the daily note's review section so
   the pattern is tracked. The captain has accepted aggressive-for-now.
