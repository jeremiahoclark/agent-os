#!/usr/bin/env bash
# Bootstrap detection, best-effort fleet refresh/prune, and installs.
# Usage: aos-bootstrap.sh
#          Detect: prints one line per problem or capability fact and exits 0.
#          Silent = all good.
#          Lines: "MISSING: <tool> (install: <command>)", "NEEDS_GH_AUTH",
#                 "SETUP_REQUIRED",
#                 "SUBAGENT_HARNESS_OVERRIDE: <name>",
#                 "FLEET_SYNC: <repo>: skipped|recovered|STUCK: <detail>",
#                 "TASKS_AXI: available", "TANGLE: <remediation>",
#                 "SECONDARY_SUBAGENT_SYNC: secondary_subagent <id>: skipped: <reason>",
#                 "NUDGE_SECONDARY_SUBAGENTS: <window-targets...>",
#                 "AOSX: X mode on ..." or "AOSX: X mode off ...".
#          A NUDGE_SECONDARY_SUBAGENTS line lists the RUNNING secondary_subagent windows whose
#          worktree was fast-forwarded to maestro's own current default-branch
#          commit (a purely LOCAL fast-forward, never an origin fetch) AND whose
#          instruction surface actually changed; maestro nudges each to re-read.
#          Already-current or no-instruction-change homes are silently left alone.
#          SECONDARY_SUBAGENT_SYNC lines report actionable skipped local-HEAD syncs for
#          live secondary_subagent homes; no-op/current and successful updates stay quiet.
#          A TANGLE line means the maestro primary checkout (AOS_ROOT) is stranded
#          on a feature branch instead of its default branch - a subagent's work
#          landed in the primary instead of its own worktree; restore it per the line.
#          treehouse is also MISSING when its installed version lacks
#          "treehouse get --lease" support.
#          no-mistakes is also MISSING when its installed version is older than
#          1.31.2.
#          tasks-axi is an OPTIONAL backlog-management capability reported only
#          when tasks-axi --version is 0.1.1 or newer. It is never a MISSING
#          line and never prompts an install.
#          X mode is OPTIONAL and inert unless AOS_HOME/.env has a non-empty
#          AOSX_PAIRING_TOKEN. When opted in, bootstrap requires curl+jq, writes
#          the relay poll shim and 30s cadence config, and prints an AOSX line.
#          Fleet sync fetches, fast-forwards safe default-branch states, reports
#          recovered and STUCK clone drift, and prunes gone local branches; it is
#          bounded by AOS_FLEET_SYNC_BOOTSTRAP_TIMEOUT, default 20s.
#          Set AOS_FLEET_PRUNE=0 to skip branch pruning during that refresh.
#        aos-bootstrap.sh install <tool>...
#          Install the named tools (only ones the owner approved).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AOS_ROOT="${AOS_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
AOS_HOME="${AOS_HOME:-${AOS_ROOT_OVERRIDE:-$AOS_ROOT}}"
PROJECTS="${AOS_PROJECTS_OVERRIDE:-$AOS_HOME/projects}"
CONFIG="${AOS_CONFIG_OVERRIDE:-$AOS_HOME/config}"
STATE="${AOS_STATE_OVERRIDE:-$AOS_HOME/state}"
# shellcheck source=bin/aos-tasks-axi-lib.sh
. "$SCRIPT_DIR/aos-tasks-axi-lib.sh"
# shellcheck source=bin/aos-tangle-lib.sh
. "$SCRIPT_DIR/aos-tangle-lib.sh"
# shellcheck source=bin/aos-ff-lib.sh
. "$SCRIPT_DIR/aos-ff-lib.sh"
# shellcheck source=bin/aos-x-lib.sh
. "$SCRIPT_DIR/aos-x-lib.sh"

fleet_sync() {
  [ -x "$AOS_ROOT/bin/aos-fleet-sync.sh" ] || return 0
  [ -d "$PROJECTS" ] || return 0

  tmp=$(mktemp "${TMPDIR:-/tmp}/aos-fleet-sync.XXXXXX" 2>/dev/null) || return 0
  monitor_was_on=0
  case $- in *m*) monitor_was_on=1 ;; esac
  set -m 2>/dev/null || true
  "$AOS_ROOT/bin/aos-fleet-sync.sh" >"$tmp" 2>/dev/null &
  pid=$!

  timeout=${AOS_FLEET_SYNC_BOOTSTRAP_TIMEOUT:-20}
  case "$timeout" in ''|*[!0-9]*) timeout=20 ;; esac
  start=$SECONDS
  while jobs -r -p | grep -qx "$pid"; do
    if [ $((SECONDS - start)) -ge "$timeout" ]; then
      kill -TERM "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      [ "$monitor_was_on" -eq 1 ] || set +m 2>/dev/null || true
      echo "FLEET_SYNC: fleet: skipped: bootstrap refresh timed out"
      rm -f "$tmp"
      return 0
    fi
    sleep 1
  done
  wait "$pid" 2>/dev/null || true
  [ "$monitor_was_on" -eq 1 ] || set +m 2>/dev/null || true

  while IFS= read -r line; do
    case "$line" in
      *': skipped: local-only project') ;;
      *': skipped: no origin remote') ;;
      *': skipped:'*) echo "FLEET_SYNC: $line" ;;
      *': STUCK:'*) echo "FLEET_SYNC: $line" ;;
      *': recovered:'*) echo "FLEET_SYNC: $line" ;;
    esac
  done < "$tmp"
  rm -f "$tmp"
}

secondary_subagent_sync() {
  # Local-HEAD secondary_subagent sync: fast-forward every LIVE secondary_subagent home's worktree
  # to the primary checkout's current default-branch commit. Purely LOCAL - no
  # fetch, no origin dependency: a secondary_subagent home is a worktree of this same repo
  # and already holds the primary's commit (aos-ff-lib.sh). Emits NUDGE_SECONDARY_SUBAGENTS:
  # only for RUNNING secondary_subagents whose instruction surface actually changed, so a
  # secondary_subagent already on the primary's version is never disturbed (AGENTS.md
  # bootstrap + supervision). Mirrors aos-update's nudge_secondary_subagents: report so
  # maestro can live-converge the listed windows.
  [ -d "$STATE" ] || return 0
  local primary_head
  if ! primary_head=$(primary_head_commit "$AOS_ROOT"); then
    local meta id
    for meta in "$STATE"/*.meta; do
      [ -f "$meta" ] || continue
      grep -q '^kind=secondary_subagent' "$meta" 2>/dev/null || continue
      id=$(basename "$meta" .meta)
      echo "SECONDARY_SUBAGENT_SYNC: secondary_subagent $id: skipped: primary default-branch commit cannot be resolved"
    done
    return 0
  fi
  FF_NUDGE_WINDOWS=""
  FF_SEEN_HOMES=""
  local tmp line
  tmp=$(mktemp "${TMPDIR:-/tmp}/aos_secondary_subagent_sync.XXXXXX" 2>/dev/null) || return 0
  sweep_live_secondary_subagent_metas "$STATE" "$primary_head" yes >"$tmp"
  while IFS= read -r line; do
    case "$line" in
      secondary_subagent\ *': skipped:'*) echo "SECONDARY_SUBAGENT_SYNC: $line" ;;
    esac
  done < "$tmp"
  rm -f "$tmp"
  [ -n "$FF_NUDGE_WINDOWS" ] && echo "NUDGE_SECONDARY_SUBAGENTS:$FF_NUDGE_WINDOWS"
  return 0
}

install_cmd() {
  case "$1" in
    tmux|node|gh|curl|jq) echo "brew install $1  # or the platform's package manager" ;;
    treehouse) echo "curl -fsSL https://kunchenguid.github.io/treehouse/install.sh | sh" ;;
    no-mistakes) echo "curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh" ;;
    gh-axi|chrome-devtools-axi|lavish-axi) echo "npm install -g $1 && $1 setup hooks" ;;
    *) return 1 ;;
  esac
}

TOOLS="tmux node gh treehouse no-mistakes gh-axi chrome-devtools-axi lavish-axi"
NO_MISTAKES_MIN_MAJOR=1
NO_MISTAKES_MIN_MINOR=31
NO_MISTAKES_MIN_PATCH=2

treehouse_supports_lease() {
  treehouse get --help 2>&1 | grep -Eq '(^|[^[:alnum:]_-])--lease([^[:alnum:]_-]|$)'
}

no_mistakes_version_parts() {
  local output
  command -v no-mistakes >/dev/null 2>&1 || return 1
  output=$(no-mistakes --version 2>/dev/null) || return 1
  printf '%s\n' "$output" | sed -nE 's/.*[vV]?([0-9]+)\.([0-9]+)\.([0-9]+).*/\1 \2 \3/p' | head -n 1
}

no_mistakes_compatible() {
  local parts major minor patch extra
  parts=$(no_mistakes_version_parts) || return 1
  IFS=' ' read -r major minor patch extra <<< "$parts"
  [ -n "$major" ] && [ -n "$minor" ] && [ -n "$patch" ] && [ -z "$extra" ] || return 1
  [ "$major" -gt "$NO_MISTAKES_MIN_MAJOR" ] && return 0
  [ "$major" -eq "$NO_MISTAKES_MIN_MAJOR" ] || return 1
  [ "$minor" -gt "$NO_MISTAKES_MIN_MINOR" ] && return 0
  [ "$minor" -eq "$NO_MISTAKES_MIN_MINOR" ] || return 1
  [ "$patch" -ge "$NO_MISTAKES_MIN_PATCH" ]
}

# Write CONTENT to DEST only when it differs, so re-running bootstrap does not
# churn mtimes or duplicate generated files (idempotence).
write_if_changed() {
  local dest=$1 content=$2
  [ -f "$dest" ] && [ "$(cat "$dest" 2>/dev/null)" = "$content" ] && return 0
  printf '%s\n' "$content" > "$dest"
}

# X mode (opt-in): when this home's .env carries a non-empty AOSX_PAIRING_TOKEN,
# wire the relay poll into the EXISTING watcher check mechanism without touching
# aos-watch.sh or any other watcher-backbone file. Drops two idempotent,
# gitignored artifacts:
#   state/x-watch.check.sh - check shim that execs bin/aos-x-poll.sh each cycle
#   config/x-mode.env      - exports AOS_CHECK_INTERVAL=30, sourced by the watcher
#                            arm so only an X instance polls at the 30s cadence
# On opt-out (no token, or empty) it removes any such artifacts so the instance
# reverts to the default 300s no-poll behavior. Absent a token AND with no leftover
# artifacts it is a complete no-op (nothing written, nothing printed), so a non-X
# user sees zero change. Prints one confirmation line on opt-in, and one on opt-out
# only when it actually removed artifacts. It never touches the watcher itself;
# applying a cadence transition to a running watcher is the caller's job via
# 'bin/aos-watch-arm.sh --restart' (see AGENTS.md "X mode").
x_mode_setup() {
  local env_file token shim cadence shim_body cadence_body tool missing
  env_file="$AOS_HOME/.env"
  shim="$STATE/x-watch.check.sh"
  cadence="$CONFIG/x-mode.env"

  token=
  [ -f "$env_file" ] && token=$(fmx_env_get AOSX_PAIRING_TOKEN "$env_file")

  x_mode_remove_artifacts() {
    rm -f "$shim" "$cadence" 2>/dev/null || true
    [ ! -e "$shim" ] && [ ! -e "$cadence" ]
  }

  if [ -z "$token" ]; then
    # Opt-out (or never opted in): drop any X artifacts; stay silent unless we
    # actually removed something.
    if [ -e "$shim" ] || [ -e "$cadence" ]; then
      if x_mode_remove_artifacts; then
        echo "AOSX: X mode off - removed relay poll shim and 30s cadence; restart the watcher (bin/aos-watch-arm.sh --restart) to drop back to the default cadence"
      else
        echo "AOSX: X mode off - failed to remove relay poll shim or 30s cadence"
      fi
    fi
    return 0
  fi

  missing=0
  for tool in curl jq; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      echo "MISSING: $tool (install: $(install_cmd "$tool"))"
      missing=1
    fi
  done
  if [ "$missing" -ne 0 ]; then
    if [ -e "$shim" ] || [ -e "$cadence" ]; then
      if x_mode_remove_artifacts; then
        echo "AOSX: X mode off - missing relay poll dependencies; install them and rerun bootstrap"
      else
        echo "AOSX: X mode off - failed to remove relay poll shim or 30s cadence after missing relay poll dependencies"
      fi
    fi
    return 0
  fi

  fmx_arm_failed() {
    if x_mode_remove_artifacts; then
      echo "AOSX: X mode off - failed to arm relay poll shim or 30s cadence"
    else
      echo "AOSX: X mode off - failed to arm relay poll shim or 30s cadence; stale artifacts remain"
    fi
  }

  mkdir -p "$STATE" "$CONFIG" 2>/dev/null || { fmx_arm_failed; return 0; }

  shim_body=$(cat <<EOF
#!/usr/bin/env bash
# Auto-generated by aos-bootstrap.sh - X mode connector poll shim.
# The watcher runs this each check cycle; output becomes a check: wake.
export AOS_HOME=$(printf '%q' "$AOS_HOME")
exec $(printf '%q' "$AOS_ROOT/bin/aos-x-poll.sh")
EOF
)
  write_if_changed "$shim" "$shim_body" || { fmx_arm_failed; return 0; }
  chmod +x "$shim" 2>/dev/null || { fmx_arm_failed; return 0; }

  cadence_body=$(cat <<'EOF'
# Auto-generated by aos-bootstrap.sh - X mode watcher cadence.
# Source this before arming the watcher (see AGENTS.md "X mode") so aos-watch.sh
# polls the X check every 30s. Non-X instances have no such file and keep the
# default 300s cadence.
export AOS_CHECK_INTERVAL=30
EOF
)
  write_if_changed "$cadence" "$cadence_body" || { fmx_arm_failed; return 0; }

  echo "AOSX: X mode on - relay poll armed via state/x-watch.check.sh; 30s watcher cadence in config/x-mode.env"
}

if [ "${1:-}" = "install" ]; then
  shift
  [ $# -gt 0 ] || { echo "usage: aos-bootstrap.sh install <tool>..." >&2; exit 1; }
  for t in "$@"; do
    cmd=$(install_cmd "$t") || { echo "error: unknown tool $t" >&2; exit 1; }
    cmd=${cmd%%  #*}
    echo "installing $t: $cmd"
    eval "$cmd"
  done
  exit 0
fi

DATA="${AOS_DATA_OVERRIDE:-$AOS_HOME/data}"
# First-run / re-setup gate. Maestro must begin automatic setup before fleet work.
if [ -f "$CONFIG/setup-pending" ] || [ ! -f "$DATA/owner.md" ]; then
  echo "SETUP_REQUIRED"
fi

for t in $TOOLS; do
  command -v "$t" >/dev/null || echo "MISSING: $t (install: $(install_cmd "$t"))"
done
if command -v treehouse >/dev/null 2>&1 && ! treehouse_supports_lease; then
  echo "MISSING: treehouse (install: $(install_cmd treehouse))"
fi
if command -v no-mistakes >/dev/null 2>&1 && ! no_mistakes_compatible; then
  echo "MISSING: no-mistakes (install: $(install_cmd no-mistakes))"
fi
gh auth status >/dev/null 2>&1 || echo "NEEDS_GH_AUTH"
# Worktree-tangle check: the maestro primary checkout (AOS_ROOT) must sit on its
# default branch, not a feature branch (see aos-tangle-lib.sh). Scoped to the
# primary only; detached-HEAD worktrees and secondary_subagent homes never trip it.
tangle_branch=$(fm_primary_tangle_branch "$AOS_ROOT" 2>/dev/null || true)
if [ -n "$tangle_branch" ]; then
  tangle_default=$(fm_default_branch "$AOS_ROOT" 2>/dev/null || echo main)
  echo "TANGLE: primary checkout on feature branch '$tangle_branch' (expected '$tangle_default'); the work is safe on that ref - restore the primary with: git -C $AOS_ROOT checkout $tangle_default, then re-validate the branch in a proper worktree"
fi
harness=
[ -f "$CONFIG/subagent-harness" ] && harness=$(tr -d '[:space:]' < "$CONFIG/subagent-harness" || true)
[ -n "$harness" ] && [ "$harness" != "default" ] && echo "SUBAGENT_HARNESS_OVERRIDE: $harness"
fm_tasks_axi_compatible && echo "TASKS_AXI: available"
secondary_subagent_sync
x_mode_setup
fleet_sync
exit 0
