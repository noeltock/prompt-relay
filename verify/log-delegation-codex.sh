#!/usr/bin/env bash
# log-delegation-codex.sh — append one routing-log row per Codex subagent.
#
# Codex counterpart to log-delegation.sh. Wire as a SubagentStop hook in
# ~/.codex/hooks.json (see this dir's README.md).
#
# Why this one is NOT optional on Codex:
#   multi_agent is on by default and the disable flags were reported unreliable
#   at 0.145.0 (`--disable multi_agent --disable multi_agent_v2` still spawned
#   subagents). You cannot reliably switch fan-out off — you can only pin what it
#   costs and watch it. This log is the watching half. One user measured weekly
#   usage going 1% -> 33% in ~25 minutes from 20 unintended subagents; that is
#   the failure this exists to make visible on the first occurrence.
#
# Unlike the Claude version, the field paths here are NOT guesses. They come from
# the subagent-stop.command.input JSON schema in codex-cli 0.145.0:
#   agent_id · agent_type · agent_transcript_path · model · cwd · session_id
#   turn_id · permission_mode · hook_event_name · last_assistant_message
#   stop_hook_active
set -euo pipefail

LOG="${ROUTING_LOG:-$HOME/.codex/routing-log.jsonl}"
mkdir -p "$(dirname "$LOG")"

event="$(cat)"   # Codex passes the stop event as JSON on stdin

# Straight from the documented payload — no enrichment needed for these.
role="$(printf '%s' "$event"     | jq -r '.agent_type // "unknown"')"
model="$(printf '%s' "$event"    | jq -r '.model // "unknown"')"
agent_id="$(printf '%s' "$event" | jq -r '.agent_id // ""')"
session="$(printf '%s' "$event"  | jq -r '.session_id // ""')"
cwd="$(printf '%s' "$event"      | jq -r '.cwd // ""')"

# Codex does not put token counts or duration in the stop event. The transcript
# does. Left blank rather than faked — a zero here would read as "free", which is
# the opposite of the thing this log exists to catch.
transcript="$(printf '%s' "$event" | jq -r '.agent_transcript_path // ""')"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

jq -cn \
  --arg ts "$ts" --arg role "$role" --arg model "$model" \
  --arg agent_id "$agent_id" --arg session "$session" \
  --arg cwd "$cwd" --arg transcript "$transcript" \
  '{ts:$ts, harness:"codex", role:$role, model:$model,
    agent_id:$agent_id, session_id:$session, cwd:$cwd,
    transcript_path:$transcript}' \
  >> "$LOG"

# The one query that matters, run it weekly:
#   jq -r '.model' ~/.codex/routing-log.jsonl | sort | uniq -c | sort -rn
# Every row should show your pinned cheap tier. A flagship model in this column
# means default_subagent_model is not taking effect and your routing policy is
# advisory rather than enforced.
