# The bin/ toolbelt

Maestro drives these; interactive entrypoints work by hand too, while `*-lib.sh` files are sourced helpers.
Each file also starts with a short header comment.

| Script                   | Description                                                                                                         |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------- |
| `aos-bootstrap.sh`        | Detect required toolchain and version problems, optional capability facts, primary-checkout `TANGLE:` problems, and actionable clone refresh outcomes; refresh project clones best-effort; locally sync live secondary-subagent homes; set up opt-in X mode; install tools only after consent |
| `aos-fleet-sync.sh`       | Fetch clones, fast-forward safe default-branch states, self-heal clean detached ancestor drift, report unsafe drift as `STUCK:`, and safely prune branches whose remote is gone |
| `aos-update.sh`           | Self-update the running maestro repo and registered secondary-subagent homes with fast-forward-only pulls from origin     |
| `aos-backlog-handoff.sh`  | Move already-judged in-scope queued backlog items from the main home into a seeded secondary-subagent home                 |
| `aos-brief.sh`            | Scaffold a ship brief with a worktree-isolation assertion, a report-only scout brief with `--scout`, or a secondary-subagent charter with `--secondary_subagent` |
| `aos-ensure-agents-md.sh` | Ensure project `AGENTS.md` is the real memory file and `CLAUDE.md` symlinks to it                                   |
| `aos-guard.sh`            | Warn when the primary checkout is tangled, when queued wakes are pending, or when a stale or missing watcher needs a prominent banner |
| `aos-home-seed.sh`        | Lease/provision a secondary-subagent home transactionally, clone projects, initialize gates, and maintain `data/secondary_subagents.md` |
| `aos-spawn.sh`            | Spawn one task, several `id=repo` pairs, or a persistent secondary-subagent with `--secondary_subagent`; ship/scout spawns require an isolated treehouse worktree; secondary-subagent spawns locally sync the home before launch |
| `aos-project-mode.sh`     | Resolve a project's delivery mode and `+yolo` flag from `data/projects.md`                                          |
| `aos-merge-local.sh`      | Fast-forward a `local-only` project's local default branch after approval                                           |
| `aos-review-diff.sh`      | Review a subagent branch against the authoritative base, with optional `--stat` output                              |
| `aos-marker-lib.sh`       | Shared from-maestro request marker and detector sourced by `aos-send.sh`, `aos-brief.sh`, and tests                 |
| `aos-watch-arm.sh`        | Verified per-home watcher re-arm; reports `started`, `healthy`, or `FAILED`; `--restart` relaunches only this home's watcher |
| `aos-watch.sh`            | Singleton-safe always-on watcher; absorbs no-verb signal and stale wakes only when the crew is provably working, queues and exits for actionable wakes, and reverts to daemon-owned one-shot behavior while `state/.afk` exists |
| `aos-supervise-daemon.sh` | Presence-gated sub-supervisor for walk-away (`/afk`) supervision: wraps `aos-watch.sh`, uses the shared wake classifier, self-handles routine wakes in bash, and escalates only owner-relevant events as one verified, batched, single-line digest prefixed with a sentinel marker |
| `aos-subagent-state.sh`       | Print one stable current-state line for a crew by reconciling its matching no-mistakes run-step, even when the pane has closed, with pane and status-log fallback |
| `aos-tangle-lib.sh`       | Shared default-branch resolution and primary-checkout tangle classification sourced by bootstrap and guard         |
| `aos-ff-lib.sh`           | Shared guarded fast-forward helper for `/update-agentos` origin pulls and no-fetch local secondary-subagent syncs         |
| `aos-tasks-axi-lib.sh`    | Shared `tasks-axi` compatibility probe sourced by bootstrap and teardown                                            |
| `aos-wake-drain.sh`       | Atomically drain queued watcher wakes before handling supervision work, then run the watcher-liveness guard         |
| `aos-wake-lib.sh`         | Shared durable wake queue and portable lock helpers sourced by the watcher, drain, arm, guard, and daemon          |
| `aos-classify-lib.sh`     | Shared owner-relevant wake classifier sourced by the watcher and daemon, plus the watcher's provably-working predicate |
| `aos-send.sh`             | Send one verified literal line (or `--key Escape`) to a direct-report window; exits non-zero on confirmed swallowed Enter; bare `kind=secondary_subagent` targets are marked as from-maestro; slash commands and codex `$...` skill invocations get popup-settle before Enter; text sends pause `AOS_SEND_SETTLE` seconds after success |
| `aos-tmux-lib.sh`         | Shared tmux pane primitives for busy detection, dim-ghost-aware and border-aware composer detection, and verified submit retry |
| `aos-peek.sh`             | Print a bounded tail of a subagent pane                                                                             |
| `aos-pr-check.sh`         | Record `pr=` and a verified `pr_head=` when available for a PR-ready task, then arm the watcher's merge poll        |
| `aos-promote.sh`          | Promote a scout task in place so it becomes a protected ship task                                                   |
| `aos-teardown.sh`         | Return a clean, landed ship worktree or retire/release a secondary-subagent home; requires scout reports, checks child work, and prints the backlog reminder |
| `aos-harness.sh`          | Detect the running harness; resolve the effective subagent harness                                                  |
| `aos-lock.sh`             | Per-home maestro session lock                                                                                     |
| `aos-x-lib.sh`            | Shared X-mode `.env`, alternate env-file, relay, dry-run config, reply-thread splitting, and task-to-X-request meta-link helpers |
| `aos-x-poll.sh`           | Do one bounded X relay poll; without `AOSX_PAIRING_TOKEN` it is silent, with a pending mention it stashes the full inbox JSON, including `in_reply_to`, and prints `x-mention <request_id>` |
| `aos-x-reply.sh`          | Post or dry-run preview a composed public-safe X answer or `--followup`, auto-splitting long text into `{request_id,text,texts}` threads; reads text from an argument, stdin, or `--text-file` |
| `aos-x-dismiss.sh`        | Dismiss or dry-run preview a skipped X mention without replying by sending `{request_id}` to the relay's `connector/dismiss` endpoint |
| `aos-x-link.sh`           | Link a spawned task to its originating X mention by recording `x_request=` and `x_request_ts=` in `state/<id>.meta` |
| `aos-x-followup.sh`       | Detect, post, and clear the single completion follow-up for an X-linked task, enforcing the local 24h window and retrying only when the relay post fails |
