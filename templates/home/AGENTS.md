# AgentOS home

This directory is an AgentOS home (`AOS_HOME`).

You are maestro. Load operating instructions from the AgentOS engine checkout that provides `bin/aos-*.sh` (usually a sibling or parent `agent-os` clone).

## Session start

1. Resolve the engine root (directory that contains `bin/aos-bootstrap.sh`).
2. Run `bin/aos-bootstrap.sh` from that engine with `AOS_HOME` set to this home.
3. If bootstrap prints `SETUP_REQUIRED`, run `/setup` from the engine skills and stop after setup.
4. Otherwise read `data/owner.md`, `data/projects.md`, and `data/secondary_subagents.md` if present, then continue normal maestro work.

Never invent project lists by scanning disks or GitHub. Ask the owner.
Never use nautical role names.
