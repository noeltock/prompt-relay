#!/usr/bin/env bash
# scout-model-pin.sh — deterministic model pin for built-in scout agent types.
#
# Problem: Explore/general-purpose are built-in Claude Code agent types with
# no ~/.claude/agents/*.md file, so there is no frontmatter to set a default
# model on. Left unpinned they inherit the session model at spawn time --
# so on an Opus/Fable lead session, a "quick" scout costs flagship rates.
# A prose line in CLAUDE.md asking the lead to pass model:sonnet is
# unreliable (recency bias, gets dropped under context pressure); this hook
# rewrites the call instead of asking nicely.
#
# This hook rewrites the Task tool_input directly via hookSpecificOutput's
# updatedInput field, which the schema documents as PreToolUse-only genuine
# input mutation (not just advisory additionalContext). It only fires when
# subagent_type is Explore or general-purpose AND no model was already
# specified in the tool call -- an explicit lead choice is never overridden.
#
# Wire: PreToolUse, matcher "Task", settings.json (additive alongside any
# other hook already on that matcher).
# Model: RELAY_SCOUT_MODEL (default "sonnet").
# Fail-open: any parse failure, missing jq, or empty stdin exits 0 silently --
# never blocks or mutates a Task spawn it can't confidently parse.
set +e
IN="$(cat)"
[ -z "$IN" ] && exit 0

command -v jq >/dev/null 2>&1 || exit 0

SUBAGENT="$(printf '%s' "$IN" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null)"
[ -z "$SUBAGENT" ] && exit 0

case "$SUBAGENT" in
  Explore|general-purpose) : ;;
  *) exit 0 ;;
esac

EXISTING_MODEL="$(printf '%s' "$IN" | jq -r '.tool_input.model // empty' 2>/dev/null)"
[ -n "$EXISTING_MODEL" ] && exit 0

SCOUT_MODEL="${RELAY_SCOUT_MODEL:-sonnet}"

UPDATED_INPUT="$(printf '%s' "$IN" | jq -c --arg m "$SCOUT_MODEL" '.tool_input + {model: $m}' 2>/dev/null)"
[ -z "$UPDATED_INPUT" ] && exit 0

jq -nc --argjson ui "$UPDATED_INPUT" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "allow", updatedInput: $ui}}' 2>/dev/null || exit 0
