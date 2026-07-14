#!/usr/bin/env bash
# log-delegation.sh — append one routing-log row per delegated sub-agent.
#
# Wire this as a SubagentStop hook in your harness (see this dir's README.md).
# It reads the stop event as JSON on stdin and appends a JSONL row. The field
# paths below match a typical Claude Code SubagentStop payload — ADJUST them to
# whatever your harness passes. task_class / model / effort aren't always in the
# event; pass them from the spawn site via the ROUTING_* env vars, or leave blank
# and enrich later.
set -euo pipefail

LOG="${ROUTING_LOG:-$HOME/.claude/routing-log.jsonl}"
mkdir -p "$(dirname "$LOG")"

event="$(cat)"   # harness passes the stop event as JSON on stdin

# --- adjust these jq paths to your harness's SubagentStop payload ---
role="$(printf '%s' "$event"   | jq -r '.subagent_type // .agent // "unknown"')"
tokens="$(printf '%s' "$event" | jq -r '.usage.output_tokens // .subagent_tokens // 0')"
dur_ms="$(printf '%s' "$event" | jq -r '.duration_ms // 0')"
duration="$(awk "BEGIN{print int(${dur_ms:-0}/1000)}")"

# these usually come from the spawn site, not the event:
task_class="${ROUTING_TASK_CLASS:-}"
model="${ROUTING_MODEL:-}"
effort="${ROUTING_EFFORT:-}"
outcome="${ROUTING_OUTCOME:-pass}"   # pass | fail | reroute | blocker

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

jq -cn \
  --arg ts "$ts" --arg tc "$task_class" --arg role "$role" \
  --arg model "$model" --arg effort "$effort" \
  --argjson tokens "${tokens:-0}" --argjson dur "${duration:-0}" \
  --arg outcome "$outcome" \
  '{ts:$ts, task_class:$tc, role:$role, model:$model, effort:$effort, tokens:$tokens, duration_s:$dur, outcome:$outcome}' \
  >> "$LOG"
