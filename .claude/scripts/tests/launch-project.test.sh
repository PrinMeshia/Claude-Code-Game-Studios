#!/usr/bin/env bash
# Contract tests for launch-project.sh. Uses a fake claude executable; no API call.
set -eu

SOURCE_ROOT="$(cd "$(dirname "$0")/../../.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/ccgs-launch-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }

FRAMEWORK="$TMP/framework"
mkdir -p "$FRAMEWORK/.claude/scripts" "$FRAMEWORK/.claude/hooks" "$FRAMEWORK/.claude/agents" "$FRAMEWORK/projects/covLab" "$FRAMEWORK/projects/occupied" "$TMP/bin"
: > "$FRAMEWORK/.claude/settings.json"
cat > "$FRAMEWORK/.claude/settings.json" <<'JSON'
{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"echo test"}]}]},"permissions":{"defaultMode":"default","deny":["Bash(rm -rf *)"]}}
JSON
: > "$FRAMEWORK/project.yaml"
: > "$FRAMEWORK/projects/covLab/project.yaml"
: > "$FRAMEWORK/projects/occupied/project.yaml"
git -C "$FRAMEWORK" init -q
git -C "$FRAMEWORK/projects/covLab" init -q
git -C "$FRAMEWORK/projects/occupied" init -q
cp "$SOURCE_ROOT/.claude/scripts/project-context.sh" "$FRAMEWORK/.claude/scripts/project-context.sh"
cp "$SOURCE_ROOT/.claude/scripts/launch-project.sh" "$FRAMEWORK/.claude/scripts/launch-project.sh"

cat > "$TMP/bin/claude" <<'CLAUDE'
#!/usr/bin/env bash
{
  printf 'cwd=%s\n' "$PWD"
  printf 'framework=%s\n' "${CCGS_FRAMEWORK_ROOT:-}"
  printf 'project=%s\n' "${CCGS_PROJECT_ROOT:-}"
  printf 'id=%s\n' "${CCGS_PROJECT_ID:-}"
  previous=""
  for arg in "$@"; do
    printf 'arg=%s\n' "$arg"
    if [ "$previous" = settings ]; then
      printf 'settings-begin\n'
      cat "$arg"
      printf '\nsettings-end\n'
      previous=""
    elif [ "$arg" = "--settings" ]; then
      previous=settings
    fi
  done
} > "$CCGS_TEST_LOG"
CLAUDE
chmod +x "$TMP/bin/claude"

export PATH="$TMP/bin:$PATH"
export CCGS_TEST_LOG="$TMP/claude.log"

(
  cd "$FRAMEWORK"
  bash .claude/scripts/launch-project.sh covLab
) || fail "launcher should start selected project"
EXPECTED_PROJECT="$(cd -P "$FRAMEWORK/projects/covLab" && pwd -P)"
EXPECTED_FRAMEWORK="$(cd -P "$FRAMEWORK" && pwd -P)"
grep -F "cwd=$EXPECTED_PROJECT" "$CCGS_TEST_LOG" >/dev/null || fail "Claude cwd is not selected project"
grep -F "project=$EXPECTED_PROJECT" "$CCGS_TEST_LOG" >/dev/null || fail "project context was not exported"
grep -F "framework=$EXPECTED_FRAMEWORK" "$CCGS_TEST_LOG" >/dev/null || fail "framework context was not exported"
grep -F "arg=--add-dir" "$CCGS_TEST_LOG" >/dev/null || fail "framework was not added as a resource directory"
grep -F '"hooks"' "$CCGS_TEST_LOG" >/dev/null || fail "session hook settings were not passed"
grep -F '"deny"' "$CCGS_TEST_LOG" >/dev/null || fail "framework permission deny rules were not passed"
if grep -F '"defaultMode"' "$CCGS_TEST_LOG" >/dev/null; then fail "framework default permission mode must not override project settings"; fi
[ -d "$FRAMEWORK/projects/covLab/.claude/hooks" ] || fail "project hooks link is missing"
[ -d "$FRAMEWORK/projects/covLab/.claude/scripts" ] || fail "project scripts link is missing"
git -C "$FRAMEWORK/projects/covLab" check-ignore -q .claude/hooks || fail "hooks link is not ignored by local Git excludes"
git -C "$FRAMEWORK/projects/covLab" check-ignore -q .claude/scripts || fail "scripts link is not ignored by local Git excludes"
STATUS="$(git -C "$FRAMEWORK/projects/covLab" status --short)"
if printf '%s\n' "$STATUS" | grep -F '?? .claude/' >/dev/null; then
  printf 'Unexpected project .claude status:\n%s\n' "$STATUS" >&2
  fail "generated runtime links must not appear as untracked files"
fi
pass "selected project is the primary working directory and shared runtime is linked"

if (
  cd "$FRAMEWORK"
  bash .claude/scripts/launch-project.sh covLab -- --worktree
) >/dev/null 2>&1; then
  fail "explicit worktree option must be rejected"
fi
pass "worktree CLI option rejected"

mkdir -p "$FRAMEWORK/projects/occupied/.claude/hooks"
printf 'keep\n' > "$FRAMEWORK/projects/occupied/.claude/hooks/custom.sh"
if (
  cd "$FRAMEWORK"
  bash .claude/scripts/launch-project.sh occupied
) >/dev/null 2>&1; then
  fail "project-owned hooks directory must not be replaced"
fi
grep -F "keep" "$FRAMEWORK/projects/occupied/.claude/hooks/custom.sh" >/dev/null || fail "existing project hook was modified"
pass "existing project hook directory is preserved and launch fails closed"

cat > "$FRAMEWORK/.claude/agents/worktree-agent.md" <<'AGENT'
---
name: worktree-agent
isolation: worktree
---
AGENT
if (
  cd "$FRAMEWORK"
  bash .claude/scripts/launch-project.sh covLab
) >/dev/null 2>&1; then
  fail "worktree-isolated agent must block direct-mode launch"
fi
rm -f "$FRAMEWORK/.claude/agents/worktree-agent.md"
pass "worktree-isolated agent frontmatter blocks launch"

(
  cd "$FRAMEWORK"
  bash .claude/scripts/launch-project.sh
) || fail "legacy root launch should remain available"
grep -F "cwd=$FRAMEWORK" "$CCGS_TEST_LOG" >/dev/null || fail "legacy mode did not keep framework root as cwd"
pass "legacy single-project launch remains available"

printf '\nAll launcher contract tests passed.\n'
