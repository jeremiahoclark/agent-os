# AgentOS home template

Copy this folder (or run `bin/aos-init-home.sh <path>`) to create a personal AgentOS home.

## Quick start

```sh
# from an agent-os engine checkout
bin/aos-init-home.sh ~/agentOS-home
cd ~/agentOS-home
claude   # or codex / opencode / pi
```

On first activation, maestro starts onboarding automatically: who you are, where projects live, which repos to add, and any secondary-subagents. Then it deletes `config/setup-pending` and will not re-ask.
