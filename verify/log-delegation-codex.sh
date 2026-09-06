#!/usr/bin/env bash
# log-delegation-codex.sh — legacy/forwarder-compatible hook log for Codex subagents.
#
# Native verification now reads Codex session transcripts directly, including the
# actual model and effort from turn_context. Keep this hook only for older installs,
# external forwarders, or a harness that already exposes a compatible SubagentStop
# feed. It is not part of the current native Codex install path.
#
# Current official Codex hook documentation establishes the shared model and transcript fields;
# these additional paths were first checked against codex-cli 0.145.0:
#   agent_id · agent_type · agent_transcript_path · model · cwd · session_id
#   turn_id · permission_mode · hook_event_name · last_assistant_message
#   stop_hook_active
# Later builds may omit model or effort. The script records "unknown" rather than
# inferring either; check-routing-codex.sh prefers transcripts for native runs.
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
  '{ts:$ts, harness:"codex", role:$role,
    observed_model:$model, observed_effort:"",
    agent_id:$agent_id, session_id:$session, cwd:$cwd,
    transcript_path:$transcript,
    evidence:(if $transcript == "" then "SubagentStop" else $transcript end)}' \
  >> "$LOG"

# For an inventory of legacy rows:
#   jq -r '[.role,.observed_model] | @tsv' ~/.codex/routing-log.jsonl | sort | uniq -c | sort -rn
# Compare the result with the installed roster. Missing model or effort data means
# the legacy feed cannot prove that part of the route; use native transcripts when
# they are available.
