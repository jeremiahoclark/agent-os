# Configuration

The files and environment variables you set to operate maestro.

## Orchestrator behavior (AGENTS.md)

The shared orchestrator behavior lives in [`AGENTS.md`](../AGENTS.md) - edit it like any prompt when the fleet is empty, or dispatch shared-repo edits to a subagent while tasks are in flight.

## Backlog backend (.tasks.toml / tasks-axi)

The tracked `.tasks.toml` pins the optional `tasks-axi` markdown backend to `data/backlog.md`, with `done_keep = 10` and an archive at `data/done-archive.md`.
When compatible `tasks-axi` is on `PATH`, maestro uses its verbs for routine backlog mutations and keeps secondary-subagent transfers behind `aos-backlog-handoff.sh` validation; without it, backlog bookkeeping remains manual.
Compatible means the shared bootstrap probe accepts `tasks-axi --version` as 0.1.1 or newer.

## Gate defaults (.no-mistakes.yaml)

The tracked `.no-mistakes.yaml` keeps test evidence outside the repo and defines `commands.test` so no-mistakes runs maestro's bash behavior suite directly.
That command requires `tmux` on `PATH`, prints `tmux -V`, runs every `tests/*.test.sh` with `bash`, and fails if any script exits non-zero.
It intentionally mirrors the behavior-test baseline in [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) instead of delegating the test step to an agent.

## Owner preferences (data/owner.md)

Personal preferences for one owner's fleet live locally in `data/owner.md`; it is gitignored and read after `data/projects.md` and optional `data/secondary_subagents.md` during bootstrap.

## Secondary-subagent routes (data/secondary_subagents.md)

Persistent secondary-subagent routes live locally in `data/secondary_subagents.md`.
Each line records the secondary-subagent id, charter summary, absolute home path, natural-language scope, project clone list, and added date; `aos-home-seed.sh validate` refuses duplicate ids, duplicate homes, and nested or overlapping homes.
The main maestro routes by reading those scopes with judgment; the project list is provisioning data, not exclusive ownership.
Use `aos-home-seed.sh <id> - <project>...` to lease a fresh maestro worktree for the secondary-subagent home.
The lease is held under the secondary-subagent id until explicit retirement or seed rollback returns it, so normal restarts do not free or recycle the home.
Teardown of a leased home fails closed if `treehouse return` cannot release the lease; plain-clone homes with no treehouse pool slot are removed directly.
Secondary-subagent routes cover `no-mistakes` and `direct-PR` projects; `local-only` projects remain main-maestro work.
For `no-mistakes` projects, seeding initializes only projects newly cloned into a secondary-subagent home and refuses to mutate a preexisting clone that is not already initialized.
After creating a secondary-subagent, move existing main-backlog items that you have judged in-scope with `aos-backlog-handoff.sh <secondary-subagent-id> <item-key>...`; it is idempotent and refuses in-flight items or non-secondary-subagent homes.
Set `AOS_SECONDARY_SUBAGENT_CHARTER` to seed from inline charter text when no filled charter brief exists; set `AOS_SECONDARY_SUBAGENT_SCOPE` when the routing scope should differ from the charter text.

## AOS_HOME

`AOS_HOME` selects the operational home for one maestro instance.
When it is unset, the repo root is the home; when it is set, scripts still run from this repo's `bin/`, but `state/`, `data/`, `config/`, and `projects/` come from `$AOS_HOME`.
`AOS_ROOT_OVERRIDE` overrides the maestro repo root used by scripts, including the primary checkout watched by the worktree-tangle guard.
When `AOS_HOME` is unset, it also behaves as the old whole-root override.
`AOS_STATE_OVERRIDE`, `AOS_DATA_OVERRIDE`, `AOS_PROJECTS_OVERRIDE`, and `AOS_CONFIG_OVERRIDE` override individual operational directories for tests and specialized harness setup.

## Harness support

claude, codex, opencode, and pi are all empirically verified; new harnesses get verified through a supervised trial task before joining the set.
The verified adapter knowledge - busy signatures, interrupt and exit commands, skill-invocation syntax, and per-harness quirks - lives in [`.agents/skills/harness-adapters/SKILL.md`](../.agents/skills/harness-adapters/SKILL.md).
Launch mechanics, including the verified command templates, live in [`bin/aos-spawn.sh`](../bin/aos-spawn.sh).

## Toolchain

On first launch maestro detects what its required toolchain is missing or too old (tmux, node, gh, treehouse with durable lease support, no-mistakes v1.31.2 or newer, gh-axi, chrome-devtools-axi, lavish-axi), lists it with the exact install commands, and installs only after you say go.
When X mode is opted in, bootstrap also requires `curl` and `jq` before arming the relay poll shim.
If compatible `tasks-axi` is already on `PATH`, bootstrap records it as an optional capability fact and maestro uses its verbs for routine backlog mutations; when it is absent or incompatible, maestro keeps hand-editing `data/backlog.md` exactly as before.
Bootstrap also reports a `TANGLE:` line when `AOS_ROOT` is on a named non-default branch; follow the printed checkout remediation rather than treating it as an installable tool problem.
Bootstrap also runs a best-effort project clone refresh through `aos-fleet-sync.sh`.
It emits `FLEET_SYNC:` for skipped refreshes that may matter, recovered self-heals, and `STUCK:` alarms; local-only and no-origin skips stay silent.
Bootstrap also runs the guarded local secondary-subagent sync for recorded live secondary-subagent homes.
It emits `SECONDARY_SUBAGENT_SYNC:` only when a home was skipped for an actionable reason, and `NUDGE_SECONDARY_SUBAGENTS:` only when a running home advanced and its instruction surface changed.

## X mode (.env)

X mode lets a maestro instance answer public `@mymaestro` mentions and act on normal reversible mention requests through maestro's normal lifecycle.
It is off unless the maestro home's gitignored `.env` contains a non-empty `AOSX_PAIRING_TOKEN`.
The pairing token both identifies the relay tenant and records opt-in consent for autonomous public replies and eligible lifecycle actions.
Destructive, irreversible, or security-sensitive asks are flagged for trusted-channel confirmation instead of being executed from a public mention.
The relay uses owner-only routing: a mention delivered to a home is from that home's owner/owner, while parent-thread context may still include other public accounts.
`AOSX_RELAY_URL` is optional and defaults to `https://mymaestro.io`, mainly for developers pointing at a local relay.
For direct client invocations, environment values override `.env`; bootstrap activation still keys off `.env` presence so watcher artifacts are explicit local opt-in state.
`AOSX_ENV_FILE` can point direct poll/reply client invocations at another `.env`-style file, but it does not change bootstrap activation.

Bootstrap turns the token into local generated state.
It writes `state/x-watch.check.sh`, a check shim that runs `bin/aos-x-poll.sh`, and `config/x-mode.env`, which exports `AOS_CHECK_INTERVAL=30` for watcher arms in that home.
When the token is removed or empty, the next bootstrap removes those artifacts.
Steady-state off is silent and writes nothing.

`bin/aos-x-poll.sh` calls `GET /connector/poll` with `Authorization: Bearer <AOSX_PAIRING_TOKEN>`.
HTTP 204 is silent.
A pending mention with non-empty `text` is stored at `state/x-inbox/<request_id>.json` and wakes maestro with `x-mention <request_id>`.
The full relay object is preserved, including `in_reply_to: {author_handle, text}` when the mention is a reply in a conversation or `null` for fresh mentions.
The `aosx-respond` skill decides whether the stashed mention is an actionable request, a question, or a pure acknowledgment.
Actionable reversible requests are run through intake, backlog, dispatch, investigation, or ship flow as appropriate.
If the work completes in that turn, the public reply reports the outcome.
If the request spawns a longer-running task, maestro posts an acknowledgement through the normal answer endpoint, links the task to the mention with `bin/aos-x-link.sh`, and posts one completion follow-up when the task reaches a terminal state.
Pure acknowledgments or mentions with nothing to answer are dismissed through `bin/aos-x-dismiss.sh` before the local inbox file is cleared.
Dismiss sends `POST /connector/dismiss` with `{request_id}`, posts no text, and tells the relay to drop the request instead of re-offering it or falling back to an offline auto-reply.
Relay auth or config problems are reported once as `x-mode-error ...` until recovery.
Live replies are posted by `bin/aos-x-reply.sh`, which sends `POST /connector/answer` with `{request_id,text}` for one-tweet replies.
Completion follow-ups use `bin/aos-x-followup.sh`, which checks the local `state/<id>.meta` link and sends the same payload shape through `POST /connector/followup` by calling `bin/aos-x-reply.sh --followup`.
The follow-up helper clears the link after a successful post or after the 24h window has elapsed; a failed post leaves the link in place so it can be retried.
If the reply exceeds `AOSX_X_REPLY_MAX_CHARS`, the client splits it into a numbered, text-only thread on word boundaries and sends `{request_id,text,texts}`, where `texts` is the ordered chunk list and `text` remains the first chunk for older relays.
`AOSX_X_REPLY_MAX_CHARS` defaults to 280 and clamps to a minimum of 50; `AOSX_X_THREAD_MAX` defaults to 25 and caps oversized replies, marking the last retained tweet with an ellipsis when truncation is needed.
`AOSX_FOLLOWUP_MAX_AGE_SECS` defaults to 86400 and controls the local completion follow-up window.

Set `AOSX_DRY_RUN` to preview replies and dismissals without posting.
Truthy means anything except unset, empty, `0`, `false`, `no`, or `off`; an explicit environment value wins over `.env`.
In dry-run, `aos-x-reply.sh` records the full would-be payload to `state/x-outbox/<request_id>.json`, including `texts` for a thread and an `endpoint` marker for follow-up previews, prints a `DRY RUN` summary to stderr, echoes the `request_id`, and exits 0.
In dry-run, `aos-x-dismiss.sh` records `{request_id, endpoint:"dismiss"}` to the same outbox path, prints a `DRY RUN` summary, echoes the `request_id`, and exits 0.
The live answer, follow-up, and dismiss bodies intentionally stay the same shape; the relay distinguishes them by endpoint.
These paths need `jq` to build the JSON payload, but they run before token and network checks, so they need neither `AOSX_PAIRING_TOKEN` nor `curl`.

## Environment variables

Runtime tuning via environment variables (defaults shown):

```sh
AOS_HOME=                 # optional operational home; unset means this repo root
AOS_ROOT_OVERRIDE=        # override maestro repo root and tangle-guard target; also legacy whole-root override when AOS_HOME is unset
AOS_STATE_OVERRIDE=       # alternate state dir, mainly for tests
AOS_DATA_OVERRIDE=        # alternate data dir, mainly for tests
AOS_PROJECTS_OVERRIDE=    # alternate projects dir, mainly for tests
AOS_CONFIG_OVERRIDE=      # alternate config dir, mainly for tests
AOS_POLL=15              # seconds between watcher poll cycles
AOS_HEARTBEAT=600        # base seconds between heartbeat scans; no-change heartbeats are absorbed while idle
AOS_HEARTBEAT_MAX=7200   # heartbeat backoff cap
AOS_CHECK_INTERVAL=300   # seconds between slow checks (merge polls or the X-mode poll shim)
AOS_CHECK_TIMEOUT=30     # seconds allowed per slow check script
AOS_SUBAGENT_STATE_NM_TIMEOUT=10   # seconds allowed per no-mistakes query inside aos-subagent-state.sh
AOS_SUBAGENT_STATE_BIN=bin/aos-subagent-state.sh   # test override for the current-state reader used by provably-working watcher triage
AOSX_PAIRING_TOKEN=      # X mode pairing token; .env opt-in authorizes replies and eligible lifecycle actions
AOSX_RELAY_URL=https://mymaestro.io   # optional X relay override, mainly for local relay development
AOSX_ENV_FILE=           # optional alternate .env file for direct X client invocations; bootstrap still checks $AOS_HOME/.env
AOSX_DRY_RUN=            # truthy previews X replies and dismissals to state/x-outbox/ without posting or requiring a token
AOSX_X_REPLY_MAX_CHARS=280   # X reply per-tweet split budget; values below 50 clamp to 50
AOSX_X_THREAD_MAX=25     # maximum tweets in one auto-split X reply thread
AOSX_FOLLOWUP_MAX_AGE_SECS=86400   # local window for posting one X completion follow-up
AOS_LOCK_STALE_AFTER=2   # seconds before dead-pid lock records can be reclaimed; mid-acquire locks keep at least 2s grace
AOS_GUARD_GRACE=300      # seconds before guard warnings and arm health checks treat a watcher beacon as stale
AOS_ARM_CONFIRM_TIMEOUT=10   # seconds aos-watch-arm waits to confirm a fresh watcher before reporting FAILED
AOS_WATCHER_STALE_GRACE=300   # defaults to AOS_GUARD_GRACE; seconds a live watcher lock may have a stale beacon before re-arm errors
AOS_SIGNAL_GRACE=30      # seconds to coalesce nearby status and turn-end signals into one wake
AOS_OWNER_RE='done:|needs-decision:|blocked:|failed:|PR ready|checks green|ready in branch|merged'   # status regex that makes watcher and daemon signal/stale/scan output owner-relevant
AOS_STALE_ESCALATE_SECS=240         # idle seconds before a provably-working non-terminal stale pane escalates; not-provably-working stale wakes surface immediately
AOS_WATCH_TRIAGE_LOG_MAX_BYTES=262144   # size cap for the watcher's absorbed-wake debug log
AOS_FLEET_SYNC_BOOTSTRAP_TIMEOUT=20   # seconds allowed for bootstrap's best-effort clone refresh
AOS_FLEET_PRUNE=1        # set to 0 to skip pruning local branches whose upstream is gone
AOS_BUSY_REGEX='esc (to )?interrupt|Working\.\.\.'   # busy-pane signatures, shared by watcher and tmux helper
AOS_COMPOSER_IDLE_RE=    # optional empty-composer regex, applied after dim-ghost and border stripping
AOS_SEND_RETRIES=3       # aos-send Enter-retry attempts after typing the line once
AOS_SEND_SLEEP=0.4       # seconds between aos-send submit checks
AOS_SEND_SETTLE=1        # seconds aos-send waits after a successful text submit; 0 disables
# sub-supervisor (bin/aos-supervise-daemon.sh); presence-gated via /afk
AOS_SUPERVISOR_TARGET=maestro:0   # supervisor tmux target (override; auto-discovers from $TMUX_PANE)
AOS_INJECT_SKIP=heartbeat           # |-prefixes force-self-handled bypassing classification; empty disables
AOS_ESCALATE_BATCH_SECS=90          # buffer window for batched escalation digests; 0 = flush immediately
AOS_MAX_DEFER_SECS=300              # max buffered escalation age before retry plus wedge alarm; 0 disables
AOS_INJECT_FAIL_SLEEP=30            # seconds to back off when the supervisor pane is unavailable
AOS_INJECT_CONFIRM_RETRIES=3        # daemon Enter-retry attempts after typing a digest once
AOS_INJECT_CONFIRM_SLEEP=0.5        # seconds between daemon submit checks
AOS_HEARTBEAT_SCAN_SECS=300         # cadence of the catch-all status scan for missed owner verbs
AOS_HOUSEKEEPING_TICK=15            # seconds between batch-flush, stale-recheck, and scan passes
AOS_CRASH_THRESHOLD=10              # watcher crashes allowed inside AOS_CRASH_WINDOW before daemon backoff
AOS_CRASH_WINDOW=60                 # seconds in the crash-loop detection window
AOS_CRASH_BACKOFF=60                # seconds to wait after crossing the crash threshold
AOS_CRASH_NORMAL_SLEEP=5            # seconds to wait after an isolated watcher crash
AOS_LOG_MAX_BYTES=1048576           # daemon log size that triggers trimming
AOS_LOG_KEEP_LINES=2000             # daemon log lines kept when trimming
```
