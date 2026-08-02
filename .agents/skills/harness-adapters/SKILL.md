---
name: harness-adapters
description: Agent-only reference for maestro harness operations. Use before spawning or recovering a subagent or secondary-subagent, handling a trust dialog, sending a harness-specific skill invocation, interrupting or exiting an agent, resuming an exited agent, or verifying a new harness adapter. Contains verified facts for claude, codex, opencode, and pi.
user-invocable: false
---

# harness-adapters

Use this reference before any harness-specific maestro operation: spawn, recovery, trust-dialog handling, skill invocation, interrupt, exit, resume, or adapter verification.

Subagents default to the same harness maestro is running on unless `config/subagent-harness` records an adapter name.
The owner may override that file at bootstrap or later; a per-task instruction such as "run this one on codex" overrides it for that dispatch only.
`default` means mirror maestro's own harness.

Each adapter splits into mechanics and knowledge.
The mechanics, including launch command, autonomy flag, and turn-end hook, live in `bin/aos-spawn.sh`.
The supervision knowledge lives here: busy signature, exit command, interrupt, dialogs, resume behavior, skill invocation, and quirks.

Never dispatch a subagent or secondary-subagent on an unverified adapter.
If `config/subagent-harness` names an unverified adapter, tell the owner and fall back to maestro's own harness until that adapter is verified.
If the owner asks for a new harness, propose verifying it first: spawn a trivial supervised task using `aos-spawn`'s raw-launch-command escape hatch, confirm every fact empirically, then record the mechanics in `aos-spawn`, the busy signature in `aos-watch.sh` and `aos-tmux-lib.sh` defaults, any needed `AOS_COMPOSER_IDLE_RE` empty-composer override, and the verified knowledge here.

## Detection

`bin/aos-harness.sh` prints maestro's own harness, using verified env markers first and then process ancestry.
`bin/aos-harness.sh crew` resolves the effective subagent harness from `config/subagent-harness`.
On `unknown`, ask the owner instead of guessing.
A owner override always beats detection.
When verifying a new adapter, record its env marker and command name in `bin/aos-harness.sh`.

For stuck recovery, the target window's harness is recorded as `harness=` in `state/<id>.meta`.
Use that value for interrupt, exit, resume, and skill-invocation facts.

## no-mistakes skill invocation

Send the validation skill using the target harness's skill invocation form.
Natural language is acceptable if uncertain.

- claude: `/<skill>`, for example `/no-mistakes`.
- codex: `$<skill>`, for example `$no-mistakes`; `/<skill>` is claude-only and codex rejects it as "Unrecognized command".
- opencode: no separate verified skill invocation beyond normal slash-command behavior; use natural language if the exact skill command is uncertain.
- pi: no separate verified skill invocation beyond normal command behavior; use natural language if the exact skill command is uncertain.

## claude (VERIFIED)

| Fact | Value |
|---|---|
| Busy-pane signature | `esc to interrupt` |
| Exit command | `/exit` |
| Interrupt | single Escape |
| Skill invocation | `/<skill>` (e.g. `/no-mistakes`) |

First launch in a fresh worktree, or first ever on a machine, may show a trust or bypass-permissions confirmation.
After every spawn, peek the pane within about 20 seconds.
If such a dialog is showing, accept it with `bin/aos-send.sh <window> --key Enter`, or the choice the dialog requires, and verify the brief started processing.

Claude renders a predicted-next-prompt suggestion as dim/faint text inside an otherwise-empty composer after a turn completes.
A plain `tmux capture-pane` cannot tell that ghost text apart from typed text.
Maestro launches every claude subagent and secondary-subagent with `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false`, scoped to maestro-launched agents through `bin/aos-spawn.sh`, so it never touches the owner's global config.
The CLI's `--prompt-suggestions` flag is print/SDK-mode only and does not suppress the interactive composer ghost text, verified empirically on v2.1.186.
As defense in depth for any pane that flag cannot reach, including the owner's own maestro composer that away-mode reads, the pane reader in `bin/aos-tmux-lib.sh` captures only the composer line with ANSI styling, drops dim/faint SGR 2 runs, and ignores them, so only normal-intensity typed text counts as pending input.
That styled capture is internal to the boolean detector only.
`aos-peek` and every other human or LLM-facing capture path stays plain `tmux capture-pane` with no escape codes.

## codex (VERIFIED 2026-06-11, codex-cli 0.139.0)

| Fact | Value |
|---|---|
| Busy-pane signature | `esc to interrupt` (shown as `• Working (Xs • esc to interrupt)`) |
| Exit command | `/quit` (slash popup needs about 1 second between text and Enter; `aos-send` handles it) |
| Interrupt | single Escape |
| Skill invocation | `$<skill>` (e.g. `$no-mistakes`); `/<skill>` is claude-only and codex rejects it as "Unrecognized command" |

A `$<skill>` invocation opens a `$`-autocomplete (skill) popup, the same hazard as the `/` slash popup: submitting too fast lets the popup swallow the Enter, so the invocation never lands.
`aos-send` handles it the same way it handles `/` - it gives the popup a longer settle (1.2s) between typing and the first Enter, with `fm_tmux_submit_core`'s retried Enter as the safety net - but the `$` settle is scoped to `harness=codex`, read from the target's `state/<id>.meta`.
That scope matters because, unlike `/`, a leading `$` commonly starts ordinary text (`$5/month`, `$HOME`), so a universal `$` rule would needlessly slow plain steers to claude/opencode/pi; only a codex target receiving a `$...` message gets the popup-settle.
An explicit `session:window` target has no meta, so its harness is unknown and treated as non-codex (the safe fast-path default).
This is why the validation trigger (`$no-mistakes`) to a codex crew now lands on the first Enter instead of biting the popup.

Directory trust dialog on first run per repo root: "Do you trust the contents of this directory?"
Accept with Enter.
The decision persists for the repo, so later worktrees of the same project skip it.

Resume after exit with `codex resume <session-id>`.
The session id is printed on quit.

## opencode (VERIFIED 2026-06-11, v1.15.7-1.17.3)

| Fact | Value |
|---|---|
| Busy-pane signature | `esc interrupt` (dotted spinner footer; note no "to") |
| Exit command | `/exit` |
| Interrupt | double Escape; known flaky while a long shell command runs, so a wedged pane may need `/exit` and relaunch |

No trust dialog.
Opencode can auto-upgrade itself in the background and the running TUI can exit mid-task, observed live from 1.15.7 to 1.17.3.
If a pane shows the exit banner, relaunch with `--continue` to resume the session.
`--prompt` does not auto-submit alongside `--continue`, so send the next instruction via `aos-send` once the TUI is up.

## pi (VERIFIED 2026-06-11)

| Fact | Value |
|---|---|
| Busy-pane signature | `Working...` (braille spinner prefix; no `esc to interrupt` text) |
| Exit command | `/quit` |
| Interrupt | single Escape |

Pi has no permission system, so subagents are always autonomous.
Keep the brief as one positional argument.
Multiple positional args become separate queued messages; `aos-spawn`'s template already does this correctly.

Project trust dialog can appear on the first pi run in any not-yet-trusted directory, observed even on clean worktrees.
Accept with Enter.
The decision persists per path in `~/.pi/agent/trust.json`, so later spawns in the same worktree slot skip it.

`aos-spawn` keeps the turn-end extension in `state/`, outside the worktree, because project-local extension files make the trust gate strictly worse and pollute the project.
The extension must listen for pi's `turn_end` event, not `agent_end`, so the watcher wakes after each completed turn instead of only when the whole agent run exits.
Pi sets `PI_CODING_AGENT=true` for its children; this is its harness-detection env marker.
