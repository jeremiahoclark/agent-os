<h1 align="center">AgentOS</h1>
<p align="center">
  <a
    href="https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue?style=flat-square"
    ><img
      alt="Platform"
      src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue?style=flat-square"
  /></a>
</p>

<h3 align="center">Talk to one agent. Delegate to subagents.</h3>

<p align="center">
  <img alt="AgentOS - talk to one agent, delegate to subagents" src="assets/banner.png" width="100%" />
</p>

## What it is

You can run one coding agent easily.
But the moment you want three project tasks done in parallel - fixes, investigations, plans, audits - you become a tab-juggler: babysitting sessions, copy-pasting context between repos, forgetting which terminal had the failing test.

AgentOS flips the model.
You talk to a single orchestrator - **maestro** - and it runs the work for you: spawning autonomous **subagents** in tmux windows, giving each a clean git worktree, supervising them to completion, and handing you finished PRs, approved local merges, or standalone investigation reports.
For larger fleets, you can opt in to persistent **secondary-subagents**: domain supervisors that are still ordinary direct reports, but run from their own isolated AgentOS homes.

There is no app to install; the orchestrator is `AGENTS.md`, bundled skills, and helper scripts that any terminal coding agent can follow.

This is not an agent harness. This is not a single skill. This is not a CLI.
This is a directory that turns any agent into your maestro, and you the owner.

AgentOS is inspired by [Kun Chen's firstmate](https://github.com/kunchenguid/firstmate) agent framework, with a stronger focus on personal home/memory setup and owner-driven onboarding.

## Features

- **One liaison** - you talk only to maestro; it dispatches, supervises, escalates only real decisions, and reports plain outcomes.
- **Visible subagents** - every subagent works in its own tmux window you can watch or type into; maestro reconciles.
- **Disposable worktrees** - each task runs in a clean [treehouse](https://github.com/kunchenguid/treehouse) git worktree, so parallel work on one repo never collides.
- **Two task shapes** - ship tasks deliver a change; scout tasks investigate, plan, reproduce, or audit and leave a report.
- **Explicit project modes** - each project ships via `no-mistakes`, `direct-PR`, or `local-only`, with an optional `+yolo` autonomy flag.
- **Optional secondary-subagents** - persistent domain supervisors in isolated homes with their own `AOS_HOME`, state, projects, and session lock.
- **Event-driven, zero-token supervision** - a bash watcher sleeps on the fleet and wakes maestro only when something needs you.
- **First-run setup** - on a fresh home, maestro asks who you are, which projects to manage and where they live, and whether to create secondary-subagents; then it saves settings and never re-asks.
- **Optional X mode** - opt in with one local `.env` token so maestro can answer public mentions through the same lifecycle as chat requests.
- **Guarded by construction** - maestro is read-only over your projects outside guarded clone refreshes, safe branch pruning, and approved `local-only` fast-forward merges; subagents make every project change behind your merge approval.
- **Restart-proof** - all state lives on disk and in tmux; kill the session anytime and the next one reconciles and carries on.

Full detail on every feature lives in [docs/architecture.md](docs/architecture.md).

## Quick Start

**Requirements:** a verified agent harness (claude, codex, opencode, or pi), git with GitHub auth, and tmux for subagent windows.
Maestro detects and offers to install everything else.

```sh
gh auth login
git clone https://github.com/jeremiahoclark/agent-os
cd agent-os && claude   # launch your harness here; AGENTS.md takes over
```

On first launch, maestro runs setup: your name, how to address you, where projects live, which repos to add, and any secondary-subagents you want. After that it just works from saved settings.

Then talk:

```sh
> look at my github project xyz, then fix the flaky login test and add dark mode

# maestro checks its toolchain (asking your consent before installing anything),
# clones the project under projects/, and spawns two subagents in tmux windows
# aos-fix-login-k3 and aos-dark-mode-p7.
# Minutes later:

  PR ready for review: https://github.com/you/xyz/pull/42
  (fix flaky login test - risk: low - CI green)

> alright merge it
```

Run it inside tmux for the best experience: launching your harness from inside tmux puts every subagent window in your own session.
Outside tmux, subagents land in a detached `agent-os` session you can attach to.

## How It Works

```
            you (the owner)
                  │  chat: requests, decisions, "merge it"
                  ▼
 ┌─────────────────────────────────────┐
 │ maestro            (this repo)      │
 │ reads projects/ + maestro routes    │
 │ writes guarded backlog/briefs/state │
 └──┬──────────────┬───────────────┬───┘
    │ tmux send-keys / status files │
    ▼              ▼               ▼
 ┌────────┐   ┌────────┐      ┌────────┐
 │aos-task1│   │aos-task2│  ... │aos-taskN│   tmux windows you can watch
 │subagent│   │subagent│      │subagent│   one autonomous agent each
 └───┬────┘   └───┬────┘      └───┬────┘
     ▼            ▼               ▼
  treehouse worktree or isolated secondary-subagent home
     │
     ├─ ship: project mode ► PR/local merge ► teardown
     │
     └─ scout: report at data/<id>/report.md ► relay findings ► teardown
```

## Built-in skills

| Skill | What it does |
| --- | --- |
| `/setup` | First-run or re-run owner/projects/secondary-subagent setup |
| `/afk` | Away-mode supervision: self-handle routine wakes, batch owner-relevant escalations |
| `/update-agentos` | Fast-forward self-update for maestro and secondary-subagents |

Agent-only reference skills live under `.agents/skills/`.

## Documentation

- [docs/architecture.md](docs/architecture.md)
- [docs/configuration.md](docs/configuration.md)
- [docs/scripts.md](docs/scripts.md)
- [`AGENTS.md`](AGENTS.md) - maestro's operating manual
- [CONTRIBUTING.md](CONTRIBUTING.md)

## License

MIT - see [LICENSE](LICENSE).
Original firstmate framework by Kun Chen; AgentOS modifications by Jeremiah Clark.
