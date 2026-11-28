#!/usr/bin/env bash
# Launch Claude Code in one selected project while reusing the shared CCGS runtime.
# The selected project remains Claude Code's primary working directory.
#
# Usage:
#   bash .claude/scripts/launch-project.sh <project-id> [--] [claude arguments...]
#   bash .claude/scripts/launch-project.sh --help
#
# This launcher installs two directory links in the selected project's .claude/
# folder (hooks/ and scripts/) only when those paths do not already exist.
# Existing project configuration is never replaced. If either path is occupied,
# the launcher stops and asks for a deliberate integration instead of merging
# or overwriting project-owned files.

set -eu

SCRIPT_DIR="$(cd -P "$(dirname "$0")" && pwd -P)"
FRAMEWORK_ROOT="$(cd -P "$SCRIPT_DIR/../.." && pwd -P)"
CONTEXT_HELPER="$SCRIPT_DIR/project-context.sh"

usage() {
  cat <<'USAGE'
CCGS project launcher

Usage:
  launch-project.sh <project-id-or-path> [--] [claude arguments...]

Examples:
  bash .claude/scripts/launch-project.sh covLab
  bash .claude/scripts/launch-project.sh covLab -- --model sonnet

The project must be a direct child of projects/ and contain project.yaml.
Claude Code starts in that project's directory; the framework is added as a
shared resource directory. Existing project .claude/hooks or .claude/scripts
directories are never overwritten.

Reserved Claude CLI options: --worktree, -w, --settings, --cwd.
USAGE
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

PROJECT_SELECTOR="${1:-}"
if [ -n "$PROJECT_SELECTOR" ]; then shift; fi
if [ "${1:-}" = "--" ]; then shift; fi

# Never allow this entrypoint to be used to opt back into isolated worktrees or
# replace the hook settings supplied by the framework.
for arg in "$@"; do
  case "$arg" in
    --worktree|-w|--settings|--settings=*|--cwd|--cwd=*)
      echo "launch-project: reserved option rejected: $arg" >&2
      echo "The launcher owns working-directory and hook configuration." >&2
      exit 2
      ;;
  esac
done

# shellcheck source=.claude/scripts/project-context.sh
. "$CONTEXT_HELPER"
ccgs_context_resolve "$PROJECT_SELECTOR" || exit 2

PROJECT_ROOT="$CCGS_PROJECT_ROOT"
PROJECT_ID="$CCGS_PROJECT_ID"
export CCGS_FRAMEWORK_ROOT="$FRAMEWORK_ROOT"
export CCGS_PROJECT_ROOT="$PROJECT_ROOT"
export CCGS_PROJECT_ID="$PROJECT_ID"

# A child project must be its own Git repository (or submodule root).
# This prevents writes from landing in an enclosing repository by accident.
if [ "$PROJECT_ID" != "." ]; then
  if ! command -v git >/dev/null 2>&1; then
    echo "launch-project: Git is required to verify the selected repository root." >&2
    exit 6
  fi
  GIT_ROOT="$(git -C "$PROJECT_ROOT" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -z "$GIT_ROOT" ]; then
    echo "launch-project: selected project is not a Git repository: $PROJECT_ROOT" >&2
    exit 6
  fi
  GIT_ROOT="$(cd -P "$GIT_ROOT" 2>/dev/null && pwd -P)"
  if [ "$GIT_ROOT" != "$PROJECT_ROOT" ]; then
    echo "launch-project: selected project is nested inside another Git repository." >&2
    echo "  selected: $PROJECT_ROOT" >&2
    echo "  git root: $GIT_ROOT" >&2
    echo "Initialize it as a repository or configure it as a submodule." >&2
    exit 6
  fi
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "launch-project: Claude Code CLI (claude) is not on PATH." >&2
  exit 127
fi

# An agent can request a worktree through its frontmatter. Do not silently run
# such an agent when the selected execution policy is direct-in-project.
USER_CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
for agents_dir in "$FRAMEWORK_ROOT/.claude/agents" "$PROJECT_ROOT/.claude/agents" "$USER_CLAUDE_DIR/agents"; do
  if [ -d "$agents_dir" ]; then
    WORKTREE_AGENTS="$(grep -R -n -E '^[[:space:]]*isolation:[[:space:]]*worktree([[:space:]]|$)' "$agents_dir" --include='*.md' 2>/dev/null || true)"
    if [ -n "$WORKTREE_AGENTS" ]; then
      echo "launch-project: worktree-isolated agent definitions found; refusing direct-mode launch:" >&2
      echo "$WORKTREE_AGENTS" >&2
      echo "Remove or explicitly redesign these isolation declarations before continuing." >&2
      exit 3
    fi
  fi
done

# Child projects reuse the framework's hooks/scripts. Existing directories are
# adopted only when their complete file trees are byte-identical to the shared
# source. The original copies are moved into the repository's private Git dir as
# a rollback/recovery backup before a link is created.
directory_has_no_symlinks() {
  local source_dir="$1" target_dir="$2"
  ! find "$source_dir" "$target_dir" -type l -print -quit 2>/dev/null | grep -q .
}

directory_is_exact_copy() {
  local source_dir="$1" target_dir="$2"
  [ -d "$source_dir" ] && [ -d "$target_dir" ] || return 1
  directory_has_no_symlinks "$source_dir" "$target_dir" || return 1
  diff -qr "$source_dir" "$target_dir" >/dev/null 2>&1
}

directory_matches_framework_history() {
  local target_dir="$1" label="$2" revision temp_dir archived_dir
  [ -d "$target_dir" ] || return 1
  directory_has_no_symlinks "$FRAMEWORK_ROOT/.claude/$label" "$target_dir" || return 1
  temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/ccgs-history-check.XXXXXX")" || return 1

  # The user may have copied the runtime before a framework update. Accept an
  # exact historical framework snapshot, but never a hand-edited/unknown tree.
  while IFS= read -r revision; do
    [ -n "$revision" ] || continue
    rm -rf "$temp_dir/archive"
    mkdir -p "$temp_dir/archive"
    if git -C "$FRAMEWORK_ROOT" archive "$revision" ".claude/$label" 2>/dev/null | tar -x -C "$temp_dir/archive" 2>/dev/null; then
      archived_dir="$temp_dir/archive/.claude/$label"
      if [ -d "$archived_dir" ] && diff -qr "$archived_dir" "$target_dir" >/dev/null 2>&1; then
        rm -rf "$temp_dir"
        return 0
      fi
    fi
  done < <(git -C "$FRAMEWORK_ROOT" rev-list --max-count=30 HEAD -- ".claude/$label" 2>/dev/null)

  rm -rf "$temp_dir"
  return 1
}

preflight_shared_directory() {
  local source_dir="$1" target_dir="$2" label="$3" actual expected
  if [ -d "$target_dir" ]; then
    actual="$(cd -P "$target_dir" 2>/dev/null && pwd -P)" || actual=""
    expected="$(cd -P "$source_dir" 2>/dev/null && pwd -P)" || expected=""
    if [ -n "$actual" ] && [ "$actual" = "$expected" ]; then
      return 0
    fi
    if directory_is_exact_copy "$source_dir" "$target_dir"; then
      return 2
    fi
    if directory_matches_framework_history "$target_dir" "$label"; then
      return 2
    fi
    echo "launch-project: refusing to replace non-identical $label directory: $target_dir" >&2
    echo "Project-specific content or symlinks may be present; no files were changed." >&2
    return 1
  fi
  if [ -e "$target_dir" ]; then
    echo "launch-project: refusing to replace existing $label path: $target_dir" >&2
    return 1
  fi
  return 0
}

ensure_shared_directory() {
  local source_dir="$1" target_dir="$2" label="$3" target_parent
  target_parent="$(dirname "$target_dir")"
  mkdir -p "$target_parent"
  if ln -s "$source_dir" "$target_dir" 2>/dev/null; then
    return 0
  fi

  # Git Bash on Windows may not be allowed to create symbolic links. A directory
  # junction is sufficient here and does not require Developer Mode/admin rights.
  if command -v cmd.exe >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1; then
    local target_win source_win
    target_win="$(cygpath -w "$target_dir")"
    source_win="$(cygpath -w "$source_dir")"
    if cmd.exe //c mklink //J "$target_win" "$source_win" >/dev/null 2>&1; then
      return 0
    fi
  fi

  echo "launch-project: could not create shared $label link at $target_dir" >&2
  echo "Use a filesystem that supports directory symlinks/junctions, then retry." >&2
  return 1
}

adopt_exact_copy() {
  local source_dir="$1" target_dir="$2" label="$3"
  local git_dir backup_root backup_path
  git_dir="$(git -C "$PROJECT_ROOT" rev-parse --absolute-git-dir 2>/dev/null)" || {
    echo "launch-project: cannot resolve Git metadata directory for safe $label adoption." >&2
    return 1
  }
  backup_root="$git_dir/ccgs-runtime-backups"
  mkdir -p "$backup_root"
  backup_path="$backup_root/$label-$(date +%Y%m%d%H%M%S)-$"
  if [ -e "$backup_path" ]; then
    echo "launch-project: backup destination already exists: $backup_path" >&2
    return 1
  fi

  if ! mv "$target_dir" "$backup_path"; then
    echo "launch-project: could not preserve existing $label copy at $backup_path" >&2
    return 1
  fi
  if ! ensure_shared_directory "$source_dir" "$target_dir" "$label"; then
    mv "$backup_path" "$target_dir" || {
      echo "CRITICAL: failed to restore $label backup from $backup_path" >&2
    }
    return 1
  fi
  echo "launch-project: adopted identical $label copy; original preserved at $backup_path" >&2
}

SETTINGS_FILE=""
cleanup() {
  if [ -n "$SETTINGS_FILE" ] && [ -f "$SETTINGS_FILE" ]; then
    rm -f "$SETTINGS_FILE"
  fi
}
trap cleanup EXIT HUP INT TERM

if [ "$PROJECT_ID" != "." ]; then
  mkdir -p "$PROJECT_ROOT/.claude"

  # Preflight both directories before moving either one. Return code 2 means an
  # exact duplicate can be adopted; 0 means absent/already linked; 1 is a hard
  # conflict and leaves the project tree untouched.
  HOOKS_STATE=0
  if preflight_shared_directory "$FRAMEWORK_ROOT/.claude/hooks" "$PROJECT_ROOT/.claude/hooks" "hooks"; then
    :
  else
    status=$?
    [ "$status" -eq 2 ] || exit 4
    HOOKS_STATE=2
  fi

  SCRIPTS_STATE=0
  if preflight_shared_directory "$FRAMEWORK_ROOT/.claude/scripts" "$PROJECT_ROOT/.claude/scripts" "scripts"; then
    :
  else
    status=$?
    [ "$status" -eq 2 ] || exit 4
    SCRIPTS_STATE=2
  fi

  if [ "$HOOKS_STATE" -eq 2 ]; then
    adopt_exact_copy "$FRAMEWORK_ROOT/.claude/hooks" "$PROJECT_ROOT/.claude/hooks" "hooks" || exit 4
  else
    ensure_shared_directory "$FRAMEWORK_ROOT/.claude/hooks" "$PROJECT_ROOT/.claude/hooks" "hooks" || exit 4
  fi

  if [ "$SCRIPTS_STATE" -eq 2 ]; then
    adopt_exact_copy "$FRAMEWORK_ROOT/.claude/scripts" "$PROJECT_ROOT/.claude/scripts" "scripts" || exit 4
  else
    ensure_shared_directory "$FRAMEWORK_ROOT/.claude/scripts" "$PROJECT_ROOT/.claude/scripts" "scripts" || exit 4
  fi

  # Keep generated links local to this checkout. Never add them to the project's
  # tracked .gitignore: they are machine-specific pointers to the framework.
  EXCLUDE_FILE="$(git -C "$PROJECT_ROOT" rev-parse --git-path info/exclude)"
  case "$EXCLUDE_FILE" in /*|[A-Za-z]:[\\/]*) ;; *) EXCLUDE_FILE="$PROJECT_ROOT/$EXCLUDE_FILE" ;; esac
  mkdir -p "$(dirname "$EXCLUDE_FILE")"
  touch "$EXCLUDE_FILE"
  if ! grep -F -x -q '/.claude/hooks' "$EXCLUDE_FILE"; then
    printf '\n# CCGS shared runtime links (generated by launch-project.sh)\n/.claude/hooks\n' >> "$EXCLUDE_FILE"
  fi
  if ! grep -F -x -q '/.claude/scripts' "$EXCLUDE_FILE"; then
    printf '/.claude/scripts\n' >> "$EXCLUDE_FILE"
  fi

  PYTHON=""
  for candidate in python python3 py; do
    if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)' >/dev/null 2>&1; then
      PYTHON="$candidate"
      break
    fi
  done
  if [ -z "$PYTHON" ]; then
    echo "launch-project: Python 3 is required to prepare the session hook settings." >&2
    exit 5
  fi

  SETTINGS_FILE="$(mktemp "${TMPDIR:-/tmp}/ccgs-hooks.XXXXXX")"
  if ! "$PYTHON" - "$FRAMEWORK_ROOT/.claude/settings.json" "$SETTINGS_FILE" <<'PY'
import json
import sys

source, target = sys.argv[1:3]
with open(source, "r", encoding="utf-8") as handle:
    settings = json.load(handle)
hooks = settings.get("hooks")
if not isinstance(hooks, dict) or not hooks:
    raise SystemExit("framework settings contain no hook definitions")
# Keep the framework's safety allow/deny rules without overriding the selected
# project's default permission mode or other project-specific settings.
permissions = settings.get("permissions", {})
session_settings = {"hooks": hooks}
if isinstance(permissions, dict):
    selected = {key: permissions[key] for key in ("allow", "deny", "ask") if key in permissions}
    if selected:
        session_settings["permissions"] = selected
with open(target, "w", encoding="utf-8") as handle:
    json.dump(session_settings, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
PY
  then
    echo "launch-project: failed to build temporary hook settings." >&2
    exit 5
  fi

  export CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1
  cd "$PROJECT_ROOT"
  claude --add-dir "$FRAMEWORK_ROOT" --settings "$SETTINGS_FILE" "$@"
  exit $?
fi

# Backward-compatible single-project mode: the framework's own .claude settings
# and hooks are already active. No extra settings or directory links are needed.
cd "$PROJECT_ROOT"
claude "$@"
