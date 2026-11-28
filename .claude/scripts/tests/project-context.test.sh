#!/usr/bin/env bash
# Portable contract tests for project-context.sh (Bash 3.2+).
set -eu

SOURCE_ROOT="$(cd "$(dirname "$0")/../../.." && pwd -P)"
RESOLVER="$SOURCE_ROOT/.claude/scripts/project-context.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/ccgs-context-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }

mkdir -p "$TMP/framework/.claude/scripts" "$TMP/framework/projects/covLab" "$TMP/framework/projects/other" "$TMP/projects/covLab"
: > "$TMP/framework/.claude/settings.json"
: > "$TMP/framework/projects/covLab/project.yaml"
: > "$TMP/framework/projects/other/project.yaml"
cp "$RESOLVER" "$TMP/framework/.claude/scripts/project-context.sh"

OUT="$(bash "$TMP/framework/.claude/scripts/project-context.sh" covLab)" || fail "explicit project id should resolve"
printf '%s\n' "$OUT" | grep -F "project_id=covLab" >/dev/null || fail "project id not returned"
printf '%s\n' "$OUT" | grep -F "project_root=$TMP/framework/projects/covLab" >/dev/null || fail "project root not canonical"
pass "explicit project id resolves"

OUT="$(bash "$TMP/framework/.claude/scripts/project-context.sh" projects/covLab)" || fail "projects/<id> path should resolve"
printf '%s\n' "$OUT" | grep -F "project_id=covLab" >/dev/null || fail "relative projects/<id> selector returned wrong id"
pass "projects/<id> relative path resolves"

OUT="$(CCGS_PROJECT_ROOT="$TMP/framework/projects/other" bash "$TMP/framework/.claude/scripts/project-context.sh")" || fail "absolute env selection should resolve"
printf '%s\n' "$OUT" | grep -F "project_id=other" >/dev/null || fail "environment selection ignored"
pass "CCGS_PROJECT_ROOT resolves"

if bash "$TMP/framework/.claude/scripts/project-context.sh" >/dev/null 2>&1; then
  fail "multi-project mode must not guess an active child"
fi
pass "ambiguous multi-project workspace fails closed"

if bash "$TMP/framework/.claude/scripts/project-context.sh" ../projects/covLab >/dev/null 2>&1; then
  fail "path traversal selector must be rejected"
fi
pass "path traversal selector rejected"

if bash "$TMP/framework/.claude/scripts/project-context.sh" projects >/dev/null 2>&1; then
  fail "projects container itself must not be accepted"
fi
pass "projects container rejected"

if bash "$TMP/framework/.claude/scripts/project-context.sh" missing >/dev/null 2>&1; then
  fail "missing project must be rejected"
fi
pass "missing project rejected"

if ln -s "$TMP" "$TMP/framework/projects/escape" 2>/dev/null; then
  if bash "$TMP/framework/.claude/scripts/project-context.sh" escape >/dev/null 2>&1; then
    fail "symlink escaping projects/ must be rejected"
  fi
  pass "symlink escape rejected"
else
  printf 'SKIP: symlink test unavailable on this platform\n'
fi

# Legacy root-project mode remains supported when there is no explicit child.
: > "$TMP/framework/project.yaml"
OUT="$(bash "$TMP/framework/.claude/scripts/project-context.sh")" || fail "legacy root mode should resolve"
printf '%s\n' "$OUT" | grep -F "project_id=." >/dev/null || fail "legacy root id not returned"
pass "legacy single-project root remains supported"

printf '\nAll project-context contract tests passed.\n'
