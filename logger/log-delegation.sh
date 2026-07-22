#!/usr/bin/env bash
# log-delegation.sh — append one routing-log row per delegated sub-agent.
#
# Wire this as a SubagentStop hook in your harness (see this dir's README.md).
# It reads the stop event as JSON on stdin and appends a JSONL row.
#
# Schema note (corrected): a real Claude Code SubagentStop payload carries
# session_id / transcript_path / cwd / permission_mode / hook_event_name /
# agent_id / agent_type — it does NOT carry subagent_type, usage/token counts,
# or duration_ms. The previous version read fields that don't exist and
# silently produced role:"unknown", tokens:0 on every single row. This version
# reads the field that actually exists (agent_type) and drops tokens/duration
# from the schema rather than fabricate them — see logger/README.md for the
# manual-capture note this implies.
#
# ROUTING_TASK_ID / ROUTING_TASK_CLASS / ROUTING_MODEL / ROUTING_EFFORT /
# ROUTING_OUTCOME have no wiring from any Claude Code spawn site (there is no
# hook point that runs "at Task-tool-call time with env access into the
# spawned agent's process" here) — treat them as an opt-in override for a
# harness that DOES pass them (e.g. a wrapper script that exports them before
# invoking claude), and document elsewhere that outcome/task_id capture is a
# manual enrichment pass over the JSONL, not automatic.
#
# Fails open: missing jq, malformed JSON, or a non-numeric/missing token count
# all fall through without crashing or blocking the SubagentStop event.
set +e

command -v jq >/dev/null 2>&1 || exit 0

LOG="${ROUTING_LOG:-$HOME/.claude/routing-log.jsonl}"
mkdir -p "$(dirname "$LOG")" 2>/dev/null

event="$(cat 2>/dev/null)"   # harness passes the stop event as JSON on stdin
[ -z "$event" ] && exit 0

# --- actual SubagentStop payload field (see note above) ---
role="$(printf '%s' "$event" | jq -r '.agent_type // .subagent_type // "unknown"' 2>/dev/null)"
[ -z "$role" ] && role="unknown"

# these come from the spawn site, not the event, and are NOT currently wired
# from any Claude Code Task-spawn point (see note above):
task_id="${ROUTING_TASK_ID:-unknown}"   # a session-scoped id, same across every delegate spawned for one lead task
task_class="${ROUTING_TASK_CLASS:-}"
model="${ROUTING_MODEL:-}"
effort="${ROUTING_EFFORT:-}"
# pass | fail | reroute | blocker-environment | blocker-decision
outcome="${ROUTING_OUTCOME:-pass}"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

jq -cn \
  --arg ts "$ts" --arg task_id "$task_id" --arg tc "$task_class" --arg role "$role" \
  --arg model "$model" --arg effort "$effort" --arg outcome "$outcome" \
  '{ts:$ts, task_id:$task_id, task_class:$tc, role:$role, model:$model, effort:$effort, outcome:$outcome}' \
  >> "$LOG" 2>/dev/null

exit 0
