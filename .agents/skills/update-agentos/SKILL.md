---
name: update-agentos
description: Self-update a running maestro and its secondary-subagents to the latest from origin. Use when the owner invokes /update-agentos (e.g. "/update-agentos", "update maestro", "pull the latest maestro"). Fast-forwards this maestro repo's default branch and every secondary-subagent home from origin (fast-forward only, never forced, never disruptive), then re-reads AGENTS.md and nudges each updated secondary-subagent to do the same, so the whole tree runs the latest bin/ and instructions.
user-invocable: true
---

# update-agentos

Self-update maestro in place.
Maestro is its own repo, behind the same no-mistakes gate as any project, so new tracked material (AGENTS.md, bin/, skills) reaches `main` and then sits there until each running maestro pulls it.
This skill performs that pull for the running main maestro and every secondary-subagent, without disturbing any in-flight work.

The update is **fast-forward only** - the same sanctioned self-write as the fleet sync maestro already runs.
It never forces, never creates a merge commit, never stashes, and advances a target only on a clean fast-forward; anything dirty, diverged, offline, or on the wrong branch is skipped and reported.
A tracked-files fast-forward leaves the gitignored operational dirs (data/, state/, config/, projects/, .no-mistakes/) untouched, so a secondary-subagent's in-flight work is never disrupted.
This touches only the maestro repo and its own worktrees, never anything under `projects/`.

## What it does

1. **Run the updater:**
   ```sh
   bin/aos-update.sh
   ```
   It fast-forwards this maestro repo's default branch from origin, then fast-forwards every registered secondary-subagent home (each a treehouse worktree of this same repo, leased at a detached HEAD on the default branch) the same way.
   It prints one status line per target (`updated <old>..<new>` / `already current` / `skipped: <reason>`), followed by two action lines that tell you exactly what to do next:
   - `reread-maestro: yes|no`
   - `nudge-secondary-subagents: <window-targets...>|none`

2. **Re-read AGENTS.md if your own instructions changed.**
   When the updater printed `reread-maestro: yes`, the tracked instruction surface (AGENTS.md, bin/, or skills) just advanced under you.
   **Read `AGENTS.md` now** (CLAUDE.md is a symlink to it) to refresh your operating instructions before doing anything else, so you are acting on the new instructions rather than the stale ones you were started with.
   When it printed `reread-maestro: no`, nothing changed for you - skip the re-read.

3. **Nudge each updated live secondary-subagent.**
   For every target listed on the `nudge-secondary-subagents:` line (do nothing when it says `none`), send a one-line re-read nudge so that secondary-subagent picks up its new instructions too:
   ```sh
   bin/aos-send.sh <window-target> 'maestro was updated to the latest - please re-read your AGENTS.md to pick up the new instructions.'
   ```
   This is a gentle steer, not an interruption: the secondary-subagent already got a safe tracked-files fast-forward, and the nudge never forces, tears down, or discards its work.
   A secondary-subagent that was skipped, already current, or has no live metadata is not on the list and needs no nudge.

4. **Report to the owner in plain outcomes.**
   Summarize what landed without maestro's internal vocabulary: which parts of the fleet are now on the latest, and which were left as-is and why.
   For example: "Owner, maestro and both domain supervisors are now on the latest."
   Surface any skipped target whose reason needs the owner's attention - for instance a home with its own un-landed changes (diverged) or local edits (dirty), which were left untouched on purpose.

## Safety

- **Fast-forward only.**
  A target that has diverged, is dirty, is offline, or is on a non-default branch is skipped and reported, never forced or stashed.
  Nothing with unlanded work is ever discarded - this is prime directive #3.
- **Only the maestro repo and its worktrees** are touched, never `projects/`.
  It is the same sanctioned self-write as the fleet sync.
- **Secondary-subagents are never disrupted.**
  A secondary-subagent gets a tracked-files fast-forward (safe while it is mid-task, since its work lives in gitignored operational dirs and separate project worktrees) plus a gentle re-read nudge.
  It is never torn down, interrupted, or forced.
