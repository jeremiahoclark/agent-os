<h1 align="center">AgentOS</h1>
<p align="center">
  <a
    href="https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue?style=flat-square"
    ><img
      alt="Platform"
      src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue?style=flat-square"
  /></a>
</p>

<h3 align="center">Talk to one agent. Let it run the rest.</h3>

## The problem

We are the bottleneck.

One coding agent is easy to manage. Add a few more and we spend our time moving context between tabs, checking terminals, answering repeated questions, and remembering what each agent is doing.

AgentOS decreases that bottleneck by putting one agent in charge of the others. You talk to **maestro**. Maestro routes the work, supervises the agents, and brings decisions back to you.

More agents can work at once. You keep one conversation.

## How it works

Open a supported coding agent harness inside this directory. That agent becomes maestro.

Maestro can:

- turn a request into separate tasks
- spawn **subagents** in tmux windows
- give each subagent a clean git worktree
- supervise work through a PR, local merge, or research report
- bring you the decisions that need your judgment

Larger setups can add **secondary-subagents**. These are persistent domain agents with their own home, backlog, and project list. They use the same lifecycle and stay available for future work.

AgentOS runs from a directory of instructions, skills, and bash helpers. Any verified terminal agent can follow it.

## Quick start

You need a coding agent harness, `git`, GitHub auth, and `tmux`.

```sh
gh auth login
git clone https://github.com/jeremiahoclark/agent-os
cd agent-os
claude # or codex / opencode / pi
```

The clone is your AgentOS home. Maestro detects supporting tools such as treehouse and no-mistakes, then asks before installing anything.

### First run

Setup starts automatically when you open the agent in this directory. There is no slash command.

Maestro asks how to address you, where your projects live, which repos to manage, and whether you want secondary-subagents. It saves those answers for later sessions.

Then talk to it normally:

```text
Look at my GitHub project xyz. Fix the flaky login test and add dark mode.
```

Maestro can clone the repo with your consent, split the request across subagents, and return with the result:

```text
PR ready for review: https://github.com/you/xyz/pull/42
Fix flaky login test. Risk: low. CI green.
```

You approve merges unless you explicitly give a project more autonomy.

### Optional separate home

Use `aos-init-home` when you want your notes and local state separated from the AgentOS repository:

```sh
bin/aos-init-home.sh ~/agentOS-home
cd ~/agentOS-home
claude
```

### tmux tip

Launch your coding agent inside tmux to see each subagent window in the same session. If you launch outside tmux, AgentOS creates a detached `agent-os` session that you can attach to later.

## How the pieces fit

```text
              you
               │
               ▼
        ┌─────────────┐
        │   maestro   │
        └──┬───────┬──┘
           │       │
           ▼       ▼
      subagent   subagent
           │       │
           ▼       ▼
       worktree  worktree
           │       │
           └───┬───┘
               ▼
      PR, local merge, or report
```

The operating model is simple:

- **Ship or research.** A ship task changes code. A research task leaves a report.
- **Choose a delivery mode.** Projects can use `no-mistakes`, `direct-PR`, or `local-only`.
- **Keep maestro read-only.** Subagents edit projects. You approve merges.
- **Persist the work.** State lives on disk and in tmux, so a later session can pick it up.
- **Wake on decisions.** A bash watcher waits quietly and wakes maestro when something needs attention.

See [the architecture docs](docs/architecture.md) for the full lifecycle.

## Useful skills

| Skill | What it does |
| --- | --- |
| `/afk` | Handles routine updates while you step away, then gives you one useful digest. |
| `/update-agentos` | Fast-forwards AgentOS and your secondary-subagent homes to the latest `main`. |

First-run setup is automatic. Ask maestro in plain language when you want to reconfigure it.

## Docs

- [Architecture](docs/architecture.md)
- [Configuration](docs/configuration.md)
- [Scripts](docs/scripts.md)
- [`AGENTS.md`](AGENTS.md), maestro’s full job description
- [Contributing](CONTRIBUTING.md)

## Credits

AgentOS started from [Kun Chen’s firstmate](https://github.com/kunchenguid/firstmate).

Modifications by Jeremiah Clark.

## License

MIT. See [LICENSE](LICENSE).
