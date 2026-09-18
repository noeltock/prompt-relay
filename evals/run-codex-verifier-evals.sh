#!/usr/bin/env bash
# Deterministic fixtures for verify/check-routing-codex.sh.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKER="$SCRIPT_DIR/../verify/check-routing-codex.sh"

command -v jq >/dev/null 2>&1 || {
  printf '%s\n' 'run-codex-verifier-evals: jq is required' >&2
  exit 1
}

FIXTURES="$(mktemp -d -t codex-routing-evals.XXXXXX)" || {
  printf '%s\n' "$(basename "$0"): mktemp -d failed, refusing to run" >&2
  exit 1
}
# An empty or non-directory FIXTURES would make the EXIT trap below operate on
# the wrong path. A Codex review of this file trashed the repository checkout
# that way (2026-09-18): mktemp failed under a sandbox, FIXTURES was empty, and
# `trash "$FIXTURES"` resolved to the working directory.
case "$FIXTURES" in
  /*) [ -d "$FIXTURES" ] || { printf '%s\n' "$(basename "$0"): fixture dir is not a directory" >&2; exit 1; } ;;
  *)  printf '%s\n' "$(basename "$0"): refusing a non-absolute fixture dir" >&2; exit 1 ;;
esac
cleanup() {
  # Never act on an unset, empty or already-removed path.
  [ -n "${FIXTURES:-}" ] && [ -d "$FIXTURES" ] || return 0
  if command -v trash >/dev/null 2>&1; then
    trash "$FIXTURES"
  else
    mkdir -p "$HOME/.Trash"
    mv "$FIXTURES" "$HOME/.Trash/codex-routing-evals-$(date +%s)"
  fi
}
trap cleanup EXIT

SESSION_DIR="$FIXTURES/sessions/2026/09/06"
mkdir -p "$SESSION_DIR"
TRANSCRIPT="$SESSION_DIR/rollout-fixture.jsonl"
ROSTER="$FIXTURES/roster"
LOG="$FIXTURES/routing-log.jsonl"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

jq -cn --arg ts "$TS" '{type:"session_meta",payload:{id:"fixture-agent",timestamp:$ts,parent_thread_id:"fixture-parent",agent_path:"/root/runner__fixture",source:{subagent:{thread_spawn:{agent_path:"/root/runner__fixture",agent_role:""}}}}}' > "$TRANSCRIPT"
jq -cn '{type:"turn_context",payload:{model:"gpt-5.6-luna",collaboration_mode:{settings:{reasoning_effort:"medium"}}}}' >> "$TRANSCRIPT"
printf '%s\n' 'runner gpt-5.6-luna medium' > "$ROSTER"
jq -cn --arg ts "$TS" '{ts:$ts,harness:"codex",role:"qa",model:"gpt-5.6-luna",effort:"medium",agent_id:"fixture-log"}' > "$LOG"

pass=0
fail=0
check() {
  local name="$1" ok="$2" detail="$3"
  if [ "$ok" -eq 1 ]; then
    printf 'PASS  %s\n' "$name"
    pass=$((pass + 1))
  else
    printf 'FAIL  %s -- %s\n' "$name" "$detail"
    fail=$((fail + 1))
  fi
}

out="$(bash "$CHECKER" --codex-home "$FIXTURES" --since 1 --roster "$ROSTER" --json)"
rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | jq -e 'select(.role == "runner" and .model == "gpt-5.6-luna" and .effort == "medium" and .status == "")' >/dev/null; then ok=1; else ok=0; fi
check 'transcript: role/model/effort match' "$ok" "rc=$rc output=$out"

printf '%s\n' 'runner gpt-5.6-terra high' > "$ROSTER"
out="$(bash "$CHECKER" --codex-home "$FIXTURES" --since 1 --roster "$ROSTER" --json)"
rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | jq -e 'select(.role == "runner" and .status == "MISMATCH")' >/dev/null; then ok=1; else ok=0; fi
check 'transcript: mismatch exits 1' "$ok" "rc=$rc output=$out"

printf '%s\n' 'runner gpt-5.6-luna medium' 'qa gpt-5.6-luna medium' > "$ROSTER"
out="$(bash "$CHECKER" --codex-home "$FIXTURES" --since 1 --roster "$ROSTER" --log "$LOG" --json)"
rc=$?
if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | jq -s 'length')" -eq 2 ]; then ok=1; else ok=0; fi
check 'legacy log: combines with transcripts' "$ok" "rc=$rc output=$out"

jq -cn --arg ts "$TS" '{ts:$ts,harness:"forwarder",role:"qa",model:"gpt-5.6-luna",effort:"medium",agent_id:"fixture-old-forwarder"}' > "$LOG"
out="$(bash "$CHECKER" --codex-home "$FIXTURES" --since 1 --roster "$ROSTER" --log "$LOG" --json)"
rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | jq -e 'select(.role == "qa" and .status == "UNVERIFIED" and .observation == "requested-only")' >/dev/null; then ok=1; else ok=0; fi
check 'legacy forwarder: requested model is not observed proof' "$ok" "rc=$rc output=$out"

jq -cn --arg ts "$TS" '{ts:$ts,harness:"forwarder",role:"qa",requested_model:"gpt-5.6-luna",requested_effort:"medium",observed_model:"unknown",observed_effort:"",evidence:"request-only",agent_id:"fixture-request"}' > "$LOG"
out="$(bash "$CHECKER" --codex-home "$FIXTURES" --since 1 --roster "$ROSTER" --log "$LOG" --json)"
rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | jq -e 'select(.role == "qa" and .status == "UNVERIFIED" and .observation == "requested-only")' >/dev/null; then ok=1; else ok=0; fi
check 'forwarder: requested route is not observed proof' "$ok" "rc=$rc output=$out"

jq -cn --arg ts "$TS" '{ts:$ts,harness:"forwarder",role:"qa",observed_model:"gpt-5.6-luna",observed_effort:"medium",evidence:"",agent_id:"fixture-no-evidence"}' > "$LOG"
out="$(bash "$CHECKER" --codex-home "$FIXTURES" --since 1 --roster "$ROSTER" --log "$LOG" --json)"
rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | jq -e 'select(.role == "qa" and .status == "UNVERIFIED")' >/dev/null; then ok=1; else ok=0; fi
check 'forwarder: observed fields without evidence stay unverified' "$ok" "rc=$rc output=$out"

jq -cn --arg ts "$TS" '{ts:$ts,harness:"forwarder",role:"qa",observed_model:"gpt-5.6-luna",observed_effort:"medium",evidence:"thread-id:fixture",agent_id:"fixture-observed"}' > "$LOG"
out="$(bash "$CHECKER" --codex-home "$FIXTURES" --since 1 --roster "$ROSTER" --log "$LOG" --json)"
rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | jq -e 'select(.role == "qa" and .status == "" and .observation == "observed")' >/dev/null; then ok=1; else ok=0; fi
check 'forwarder: independently evidenced observation can verify' "$ok" "rc=$rc output=$out"

jq -cn --arg ts "$TS" '{ts:$ts,harness:"codex",role:"qa",observed_model:"gpt-5.6-luna",observed_effort:"",evidence:"SubagentStop",agent_id:"fixture-partial"}' > "$LOG"
out="$(bash "$CHECKER" --codex-home "$FIXTURES" --since 1 --roster "$ROSTER" --log "$LOG" --json)"
rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | jq -e 'select(.role == "qa" and .status == "UNVERIFIED" and .model == "gpt-5.6-luna")' >/dev/null; then ok=1; else ok=0; fi
check 'hook: observed model without required effort is unverified' "$ok" "rc=$rc output=$out"

mkdir -p "$FIXTURES/empty"
out="$(bash "$CHECKER" --codex-home "$FIXTURES/empty" --since 1 --json)"
rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ]; then ok=1; else ok=0; fi
check 'json: empty result emits no prose' "$ok" "rc=$rc output=$out"

BAD_HOME="$FIXTURES/bad"
BAD_SESSION="$BAD_HOME/sessions/2026/09/06/rollout-bad.jsonl"
mkdir -p "$(dirname "$BAD_SESSION")"
jq -cn --arg ts "$TS" '{type:"session_meta",payload:{id:"bad-agent",timestamp:$ts,source:{subagent:{thread_spawn:{agent_path:"/root/runner__bad",agent_role:"runner"}}}}}' > "$BAD_SESSION"
printf '%s\n' '{not valid json' >> "$BAD_SESSION"
err_file="$FIXTURES/parse-error"
out="$(bash "$CHECKER" --codex-home "$BAD_HOME" --since 1 --json 2>"$err_file")"
rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ] && grep -q 'Could not parse subagent transcript:' "$err_file"; then ok=1; else ok=0; fi
check 'transcript: parse failures are surfaced' "$ok" "rc=$rc output=$out stderr=$(tr '\n' ' ' < "$err_file")"

BAD_LOG="$FIXTURES/bad-routing-log.jsonl"
printf '%s\n' '{not valid json' > "$BAD_LOG"
out="$(bash "$CHECKER" --codex-home "$FIXTURES/empty" --since 1 --log "$BAD_LOG" --json 2>"$err_file")"
rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ] && grep -q 'Could not parse routing log:' "$err_file"; then ok=1; else ok=0; fi
check 'legacy log: parse failures are surfaced' "$ok" "rc=$rc output=$out stderr=$(tr '\n' ' ' < "$err_file")"

# A worker created before a roster change can keep running its original route.
REUSED_HOME="$FIXTURES/reused"
REUSED_SESSION="$REUSED_HOME/sessions/rollout-reused.jsonl"
mkdir -p "$REUSED_HOME/sessions" "$REUSED_HOME/archived_sessions"
OLD_TS='2020-01-01T00:00:00Z'
AFTER="$(($(date +%s) - 3600))"
printf '%s\n' 'coder_low gpt-5.6-luna high' > "$ROSTER"
jq -cn --arg ts "$OLD_TS" '{type:"session_meta",payload:{id:"reused-agent",timestamp:$ts,source:{subagent:{thread_spawn:{agent_role:"coder_low",parent_thread_id:"nested-parent"}}}}}' > "$REUSED_SESSION"
jq -cn --arg ts "$OLD_TS" '{type:"turn_context",timestamp:$ts,payload:{turn_id:"old",model:"gpt-5.6-terra",effort:"medium"}}' >> "$REUSED_SESSION"
jq -cn --arg ts "$TS" '{type:"turn_context",timestamp:$ts,payload:{turn_id:"recent",model:"gpt-5.6-terra",effort:"medium"}}' >> "$REUSED_SESSION"
out="$(bash "$CHECKER" --codex-home "$REUSED_HOME" --since 3000 --after "$AFTER" --roster "$ROSTER" --json)"
rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | jq -se --arg ts "$TS" 'length == 1 and (.[0] | .ts == $ts and .turn_id == "recent" and .status == "MISMATCH" and .session_created_at == "2020-01-01T00:00:00Z" and .parent_thread_id == "nested-parent")' >/dev/null; then ok=1; else ok=0; fi
check 'after: reused worker is checked by turn time, not creation time' "$ok" "rc=$rc output=$out"

out="$(bash "$CHECKER" --codex-home "$REUSED_HOME" --since 1 --roster "$ROSTER" --json)"
rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | jq -se 'length == 1 and .[0].turn_id == "recent"' >/dev/null; then ok=1; else ok=0; fi
check 'since: excludes old turns, keeps recent work in an old session' "$ok" "rc=$rc output=$out"

jq -cn --arg ts "$TS" '{type:"turn_context",timestamp:$ts,payload:{turn_id:"corrected",model:"gpt-5.6-luna",collaboration_mode:{settings:{reasoning_effort:"high"}}}}' >> "$REUSED_SESSION"
out="$(bash "$CHECKER" --codex-home "$REUSED_HOME" --since 1 --roster "$ROSTER" --json)"
rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | jq -se 'length == 2 and .[0].status == "MISMATCH" and .[1].status == "" and .[1].turn_id == "corrected"' >/dev/null; then ok=1; else ok=0; fi
check 'history: later matching route does not hide an earlier mismatch' "$ok" "rc=$rc output=$out"

jq -cn --arg ts "$TS" '{type:"turn_context",timestamp:$ts,payload:{turn_id:"missing-fields"}}' >> "$REUSED_SESSION"
out="$(bash "$CHECKER" --codex-home "$REUSED_HOME" --since 1 --roster "$ROSTER" --json)"
rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | jq -se 'length == 3 and (.[2] | .turn_id == "missing-fields" and .status == "UNVERIFIED" and .model == "unknown" and .effort == "not recorded")' >/dev/null; then ok=1; else ok=0; fi
check 'history: missing fields are not borrowed from another turn' "$ok" "rc=$rc output=$out"

mv "$REUSED_SESSION" "$REUSED_HOME/archived_sessions/rollout-reused.jsonl"
out="$(bash "$CHECKER" --codex-home "$REUSED_HOME" --since 1 --roster "$ROSTER" --json)"
rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | jq -se 'length == 3 and all(.[]; .transcript_path | contains("/archived_sessions/"))' >/dev/null; then ok=1; else ok=0; fi
check 'archived: reused worker observations remain auditable' "$ok" "rc=$rc output=$out"

NO_CONTEXT_HOME="$FIXTURES/no-context"
mkdir -p "$NO_CONTEXT_HOME/sessions"
jq -cn --arg ts "$TS" '{type:"session_meta",payload:{id:"no-context",timestamp:$ts,source:{subagent:{thread_spawn:{agent_role:"coder_low"}}}}}' > "$NO_CONTEXT_HOME/sessions/rollout-no-context.jsonl"
out="$(bash "$CHECKER" --codex-home "$NO_CONTEXT_HOME" --since 1 --roster "$ROSTER" --json)"
rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | jq -se 'length == 1 and .[0].status == "UNVERIFIED"' >/dev/null; then ok=1; else ok=0; fi
check 'transcript: no turn context stays unverified' "$ok" "rc=$rc output=$out"

out="$(bash "$CHECKER" --codex-home "$FIXTURES/empty" --after '' --json 2>"$err_file")"
rc=$?
if [ "$rc" -eq 2 ] && [ -z "$out" ]; then ok=1; else ok=0; fi
check 'after: explicitly empty timestamp is rejected' "$ok" "rc=$rc output=$out"

printf '\nResults: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
