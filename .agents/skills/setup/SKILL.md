---
name: setup
description: Automatic first-run AgentOS owner onboarding. Load immediately at session start when bootstrap prints SETUP_REQUIRED, config/setup-pending exists, or data/owner.md is missing. Asks for identity, project locations, and secondary-subagents; writes durable settings; then disarms so later sessions never re-ask. Not a user slash command.
user-invocable: false
---

# setup

Owner-driven AgentOS onboarding. This runs automatically on first activation.
Ask; do not scan the filesystem or `gh repo list` for candidates.

## When to run

At session start, after `bin/aos-bootstrap.sh`, if any of these is true, load this skill and begin the conversation immediately — do not wait for the owner to ask, and do not wait for a slash command:

1. Bootstrap printed `SETUP_REQUIRED`
2. `config/setup-pending` exists
3. `data/owner.md` is missing

Start with the first question group in your first reply. Stop after setup completes; do not dispatch fleet work in the same turn.

## Re-run later

If the owner later asks to redo setup ("run setup again", "reconfigure AgentOS", "change my AgentOS identity"):

```sh
mkdir -p config
date '+%Y-%m-%dT%H:%M:%S%z' > config/setup-pending
```

Then walk the full flow. Existing `data/owner.md` / `data/projects.md` / `data/secondary_subagents.md` are starting points to confirm or edit, not silent defaults you keep without asking.

## Conversation flow (ask, don't discover)

Work through these steps in order. One short question group at a time. Wait for answers before writing files.

### 1. Identity

Ask:

- Preferred name
- How maestro should address them (`address_as`)
- Agent display name (default: `maestro`)
- Timezone (IANA, e.g. `America/Los_Angeles`)

### 2. Paths

Ask:

- AgentOS home path (default: current `AOS_HOME` / this directory)
- Projects root where clones should live (default: `<home>/projects`)

Create missing `data/`, `state/`, `config/`, and the projects root with consent.

### 3. Vault notes (optional)

Ask whether to create numbered note stubs:

- `01 - Daily Notes/` (include a simple Daily Note Template)
- `02 - User/`
- `03 - Preferences/`
- `04 - Projects/`

Only create folders the owner wants. Do not invent personal content.

### 4. Projects

Ask which projects AgentOS should manage and where each lives (local path or GitHub `owner/repo`).

For each accepted project:

1. Confirm ship mode: `no-mistakes`, `direct-PR`, or `local-only` (and optional `+yolo`)
2. Append/update `data/projects.md`
3. Clone into the projects root only after explicit consent per repo (or confirm an existing checkout path)

Never auto-scan `~/dev` or GitHub for candidates. If they are unsure, ask narrower follow-ups.

### 5. Secondary-subagents

Ask whether they want any persistent secondary-subagents now.

For each one they want, collect:

- id (short kebab slug)
- natural-language scope
- project list (subset of registered projects)
- short charter

Then load `secondary-subagent-provisioning` and seed with `bin/aos-home-seed.sh` / charter brief flow. Skipping this step is fine; they can add secondary-subagents later.

### 6. Write owner settings

Write `data/owner.md` using this shape:

```markdown
# Owner

- name: <display name>
- address_as: <how maestro addresses them>
- agent_name: <maestro or custom>
- timezone: <IANA timezone>
- home: <absolute AOS_HOME path>
- projects_root: <absolute projects path>

## Preferences

<optional freeform working-style notes the owner volunteered>
```

If the harness supports local settings (for example `.claude/settings.json`), write `AOS_HOME` and `AOS_PROJECTS_OVERRIDE` to match the chosen paths. Do not commit secrets.

### 7. Disarm

After the owner confirms the written settings:

```sh
rm -f config/setup-pending
```

Say clearly that the next session will load these settings and will not re-ask unless they ask to reconfigure AgentOS.

## Hard rules

- Begin automatically on first activation; never require a slash command
- Ask; do not discover project lists automatically
- Do not clone or seed without per-item consent
- Do not delete an existing `data/owner.md` until replacement content is confirmed
- After disarm, normal bootstrap only reads settings; it never re-enters this flow on its own
- Keep the tone direct and concrete; no nautical role names
