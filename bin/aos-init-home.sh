#!/usr/bin/env bash
# Copy the AgentOS home template to a new path and wire absolute settings.
# Usage: aos-init-home.sh <home-path> [projects-path]
#   home-path      destination directory for the new home (created if missing)
#   projects-path  optional projects root (default: <home-path>/projects)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AOS_ENGINE="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE="$AOS_ENGINE/templates/home"

usage() {
  echo "usage: aos-init-home.sh <home-path> [projects-path]" >&2
  exit 2
}

[ $# -ge 1 ] || usage
HOME_PATH=$1
PROJECTS_PATH=${2:-"$HOME_PATH/projects"}

if [ ! -d "$TEMPLATE" ]; then
  echo "error: home template missing at $TEMPLATE" >&2
  exit 1
fi

HOME_PATH=$(mkdir -p "$HOME_PATH" && cd "$HOME_PATH" && pwd -P)
PROJECTS_PATH=$(mkdir -p "$PROJECTS_PATH" && cd "$PROJECTS_PATH" && pwd -P)

# Copy template files without clobbering an existing configured home.
if [ -f "$HOME_PATH/data/owner.md" ] && [ ! -f "$HOME_PATH/config/setup-pending" ]; then
  echo "error: $HOME_PATH already looks configured (data/owner.md present). Refusing to overwrite." >&2
  exit 1
fi

mkdir -p "$HOME_PATH"
# Prefer rsync when available; fall back to tar for portability.
if command -v rsync >/dev/null 2>&1; then
  rsync -a --ignore-existing "$TEMPLATE"/ "$HOME_PATH"/
else
  (cd "$TEMPLATE" && tar cf - .) | (cd "$HOME_PATH" && tar xf -)
fi

mkdir -p "$HOME_PATH/data" "$HOME_PATH/state" "$HOME_PATH/config" "$PROJECTS_PATH"
date '+%Y-%m-%dT%H:%M:%S%z' > "$HOME_PATH/config/setup-pending"

settings="$HOME_PATH/.claude/settings.json"
if [ -f "$settings" ]; then
  # Portable placeholder substitution without requiring jq.
  tmp="$settings.tmp.$$"
  sed \
    -e "s|__AOS_HOME__|$HOME_PATH|g" \
    -e "s|__AOS_PROJECTS__|$PROJECTS_PATH|g" \
    -e "s|__AOS_ENGINE__|$AOS_ENGINE|g" \
    "$settings" > "$tmp"
  mv "$tmp" "$settings"
fi

cat <<EOF
initialized AgentOS home: $HOME_PATH
  engine:   $AOS_ENGINE
  projects: $PROJECTS_PATH
  setup:    armed (config/setup-pending)

Next:
  cd $(printf '%q' "$HOME_PATH")
  claude   # or your harness; first activation starts onboarding automatically
EOF
