#!/usr/bin/env bash
# pre-commit-checklist.sh — PreToolUse hook: surface the known-failures checklist
# before any `git commit` runs, so a twice-seen finding is delivered every time
# instead of relying on the model recalling it from prose.
#
# Wire as a PreToolUse hook matching the Bash tool (see this repo's README).
# Advisory only: emits hookSpecificOutput.additionalContext (the PreToolUse
# contract that actually reaches the model as a system reminder — plain stdout
# only reaches the user's transcript view, never the model) and always exits 0.
# It never blocks the commit. Turn a specific line into a real gate once you
# trust it: grep the diff for the pattern and exit 2 (blocks the tool call,
# stderr becomes the model's next instruction) instead of just surfacing it.
#
# Fails open on every path: missing jq, malformed JSON, unset vars, or a
# non-commit command all fall through to `exit 0` with no output.
set +e

command -v jq >/dev/null 2>&1 || exit 0

CHECKLIST="${KNOWN_FAILURES:-$(cd "$(dirname "$0")/.." && pwd)/learned/known-failures.md}"

event="$(cat 2>/dev/null)"   # harness passes the PreToolUse event as JSON on stdin
[ -z "$event" ] && exit 0

command_str="$(printf '%s' "$event" | jq -r '.tool_input.command // empty' 2>/dev/null)"

case "$command_str" in
  *"git commit"*) : ;;
  *) exit 0 ;;
esac

[ -f "$CHECKLIST" ] || exit 0

# Guard on actual checklist ENTRIES, not just non-empty file — the file ships
# with ~18 lines of boilerplate/doc under "## Your checklist" even when no
# finding has ever been promoted, so `-s` alone is always true from day one.
# An entry is a `- ` bullet line appearing after that heading.
ENTRIES="$(awk '/^## Your checklist/{f=1;next} f && /^- /' "$CHECKLIST" 2>/dev/null)"
[ -z "$ENTRIES" ] && exit 0

CONTEXT="$(printf 'known-failures checklist (learned/known-failures.md) — check the diff against these before this commit lands:\n%s' "$ENTRIES")"

jq -n --arg ctx "$CONTEXT" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$ctx}}' 2>/dev/null
exit 0
