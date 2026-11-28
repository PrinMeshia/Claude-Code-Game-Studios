#!/usr/bin/env bash
# Resolve the shared CCGS framework root and one explicitly selected project.
# Source this file from hooks/scripts; it is deliberately side-effect free until
# ccgs_context_resolve is called.
#
# Contract:
#   ccgs_context_resolve [project-id-or-path]
#   ccgs_context_print
#   ccgs_context_cd
#
# Selection order:
#   1. explicit argument
#   2. CCGS_PROJECT_ROOT
#   3. legacy single-project mode when the framework root has project.yaml
#
# Multi-project mode never guesses an active child from PWD.

_ccgs_context_error() {
  printf 'ccgs-context: %s\n' "$*" >&2
  return 1
}

_ccgs_context_physical_dir() {
  (cd -P "$1" 2>/dev/null && pwd -P)
}

ccgs_context_resolve() {
  local selector script_dir workspace_root projects_root selected_root selected_id
  selector="${1:-${CCGS_PROJECT_ROOT:-}}"

  script_dir="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)" || {
    _ccgs_context_error "cannot resolve script directory"
    return 1
  }
  workspace_root="$(cd -P "$script_dir/../.." 2>/dev/null && pwd -P)" || {
    _ccgs_context_error "cannot resolve framework root"
    return 1
  }
  [ -f "$workspace_root/.claude/settings.json" ] || {
    _ccgs_context_error "framework marker missing at $workspace_root"
    return 1
  }
  projects_root="$workspace_root/projects"

  if [ -z "$selector" ]; then
    # Backward compatibility: the repository root remains a valid legacy
    # project only when it owns project.yaml. Do not infer a child project.
    if [ -f "$workspace_root/project.yaml" ]; then
      selected_root="$workspace_root"
      selected_id="."
    else
      _ccgs_context_error "no project selected; pass a project id/path or set CCGS_PROJECT_ROOT"
      return 1
    fi
  else
    case "$selector" in
      /*|[A-Za-z]:[\\/]*) selected_root="$selector" ;;
      *) selected_root="$workspace_root/$selector" ;;
    esac
    selected_root="$(_ccgs_context_physical_dir "$selected_root")" || {
      _ccgs_context_error "selected project directory does not exist: $selector"
      return 1
    }

    projects_root="$(_ccgs_context_physical_dir "$projects_root")" || {
      _ccgs_context_error "projects/ directory is missing"
      return 1
    }

    # Only direct children of projects/ are valid project roots. Canonical
    # paths are compared after resolving symlinks to prevent escape.
    case "$selected_root" in
      "$projects_root"/*) ;;
      *) _ccgs_context_error "project must be a direct child of $projects_root (resolved: $selected_root)"; return 1 ;;
    esac
    selected_id="${selected_root##*/}"
    [ -n "$selected_id" ] || {
      _ccgs_context_error "could not derive project id"
      return 1
    }
    case "$selected_root" in
      "$projects_root"/*/*) _ccgs_context_error "nested project roots are not supported: $selected_root"; return 1 ;;
    esac
    [ -f "$selected_root/project.yaml" ] || {
      _ccgs_context_error "project.yaml missing in selected project: $selected_root"
      return 1
    }
  fi

  CCGS_FRAMEWORK_ROOT="$workspace_root"
  CCGS_PROJECT_ROOT="$selected_root"
  CCGS_PROJECT_ID="$selected_id"
  export CCGS_FRAMEWORK_ROOT CCGS_PROJECT_ROOT CCGS_PROJECT_ID
  return 0
}

ccgs_context_print() {
  [ -n "${CCGS_FRAMEWORK_ROOT:-}" ] && [ -n "${CCGS_PROJECT_ROOT:-}" ] || {
    _ccgs_context_error "context is unresolved; call ccgs_context_resolve first"
    return 1
  }
  printf 'framework_root=%s\nproject_root=%s\nproject_id=%s\n' \
    "$CCGS_FRAMEWORK_ROOT" "$CCGS_PROJECT_ROOT" "$CCGS_PROJECT_ID"
}

ccgs_context_cd() {
  [ -n "${CCGS_PROJECT_ROOT:-}" ] || {
    _ccgs_context_error "context is unresolved; call ccgs_context_resolve first"
    return 1
  }
  cd "$CCGS_PROJECT_ROOT" || {
    _ccgs_context_error "cannot enter project root: $CCGS_PROJECT_ROOT"
    return 1
  }
}

# CLI mode: bash project-context.sh [project-id-or-path]
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  if ! ccgs_context_resolve "${1:-}"; then
    exit 2
  fi
  ccgs_context_print
fi
