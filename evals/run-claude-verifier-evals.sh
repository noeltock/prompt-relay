#!/usr/bin/env bash
# Deterministic fixtures for verify/check-routing.sh.
#
# The Claude side had no eval harness until 2026-09-18. Its roster rules were
# only ever exercised against live transcripts, which is how a permanent false
# positive survived unnoticed: "advisor" names a role on both harnesses, the
# Codex stage runs gpt-6-astra and the Claude stage runs Fable, and one flat
# roster rule made the Claude check report MISMATCH on every advisor run.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKER="$SCRIPT_DIR/../verify/check-routing.sh"

command -v jq >/dev/null 2>&1 || {
  printf '%s\n' 'run-claude-verifier-evals: jq is required' >&2
  exit 1
}

FIXTURES="$(mktemp -d -t claude-routing-evals.XXXXXX)" || {
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
    trash "$FIXTURES" 2>/dev/null
  else
    mkdir -p "$HOME/.Trash"
    mv "$FIXTURES" "$HOME/.Trash/claude-routing-evals-$(date +%s)"
  fi
}
trap cleanup EXIT

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Build one subagent transcript plus the .meta.json sidecar the checker reads.
make_agent() {
  local name="$1" model="$2" effort="$3"
  local dir="$FIXTURES/projects/fixture/session/subagents"
  mkdir -p "$dir"
  local t="$dir/agent-$name.jsonl"
  jq -cn --arg ts "$TS" --arg m "$model" --arg e "$effort" \
    '{type:"assistant",timestamp:$ts,effort:$e,message:{model:$m,usage:{input_tokens:100,output_tokens:10}}}' > "$t"
  jq -cn --arg n "$name" '{agentType:$n,spawnDepth:1,description:("fixture " + $n)}' > "${t%.jsonl}.meta.json"
  printf '%s' "$t"
}

# Piping the checker straight into jq lets a crashed checker look like a pass:
# jq exits 0 on empty input and prints nothing, which equals the empty status
# that a satisfied rule produces. Capture first, then insist it is JSON.
checker_json() {  # roster_file transcript -> raw JSON, or aborts the case
  local roster="$1" transcript="$2" out=""
  out="$(bash "$CHECKER" --worker "$roster" "$transcript")" || {
    printf 'CHECKER-FAILED'; return 0
  }
  printf '%s' "$out" | jq -e . >/dev/null 2>&1 || { printf 'CHECKER-NOT-JSON'; return 0; }
  printf '%s' "$out"
}

run_one() {  # roster_file transcript -> status field
  local raw; raw="$(checker_json "$1" "$2")"
  case "$raw" in CHECKER-*) printf '%s' "$raw"; return 0 ;; esac
  printf '%s' "$raw" | jq -r '.status // ""'
}

# status alone cannot prove a rule MATCHED: an out-of-scope row, an absent row and
# a satisfied row all report "". Assert the rule the row was judged against.
run_expect() {  # roster_file transcript -> "status|expected_model|expected_effort"
  local raw; raw="$(checker_json "$1" "$2")"
  case "$raw" in CHECKER-*) printf '%s' "$raw"; return 0 ;; esac
  printf '%s' "$raw" \
    | jq -r '[(.status // ""), (.expected_model // ""), (.expected_effort // "")] | join("|")'
}

pass=0; fail=0
check() {
  local name="$1" got="$2" want="$3" why="$4"
  if [ "$got" = "$want" ]; then
    printf 'PASS  %s\n' "$name"; pass=$((pass+1))
  else
    printf 'FAIL  %s -- got "%s", wanted "%s" :: %s\n' "$name" "$got" "$want" "$why"; fail=$((fail+1))
  fi
}

ADVISOR="$(make_agent advisor claude-fable-5-1 medium)"
EXPLORE="$(make_agent Explore claude-haiku-4-5-20251001 high)"
QA="$(make_agent coder_low claude-sonnet-5 medium)"
QA_HIGH="$(make_agent coder_high claude-sonnet-5 high)"

# 1. THE REGRESSION. A roster carrying both advisor stages must not fail the
#    Claude one. Before harness scoping this returned MISMATCH on every run.
R="$FIXTURES/r-both"
printf '%s\n' 'codex:advisor gpt-6-astra medium' 'claude:advisor claude-fable medium' > "$R"
check "advisor: the claude-scoped row is the one applied" "$(run_expect "$R" "$ADVISOR")" "|claude-fable|medium" \
  "the load-bearing case. Asserting status alone would be inert: the pre-scoping parser also \
matched neither prefixed row and also returned an empty status, so the test would pass against \
the bug it exists to catch. Pin the rule that was actually applied."

# 2. The codex-scoped row alone must simply not apply here.
R="$FIXTURES/r-codexonly"
printf '%s\n' 'codex:advisor gpt-6-astra medium' > "$R"
check "advisor: codex-only row is out of scope, not a failure" "$(run_one "$R" "$ADVISOR")" "" \
  "an out-of-scope rule is no rule, and a row without a rule never fails"

# 3. Scoping must not become a way to smuggle a real miss past the check.
R="$FIXTURES/r-wrongmodel"
printf '%s\n' 'claude:advisor gpt-6-astra medium' > "$R"
check "advisor: a claude-scoped rule still catches a wrong model" "$(run_one "$R" "$ADVISOR")" "MISMATCH" \
  "scoping narrows which rules apply, it must not weaken the ones that do"

# 4. Backwards compatibility: every roster written before this change is bare.
R="$FIXTURES/r-legacy"
printf '%s\n' 'Explore claude-haiku' > "$R"
check "legacy: an unscoped row still matches" "$(run_one "$R" "$EXPLORE")" "" \
  "unscoped rows are the existing on-disk format -- they cannot start failing"

R="$FIXTURES/r-legacy-bad"
printf '%s\n' 'Explore claude-sonnet' > "$R"
check "legacy: an unscoped row still catches a miss" "$(run_one "$R" "$EXPLORE")" "MISMATCH" \
  "unscoped rows keep their teeth"

# 5. Effort is part of the rule, and today's pins depend on it.
R="$FIXTURES/r-effort"
printf '%s\n' 'claude:coder_low claude-sonnet medium' > "$R"
check "effort: matching effort passes" "$(run_one "$R" "$QA")" "" "coder_low is pinned to medium"

R="$FIXTURES/r-effort2"
printf '%s\n' 'claude:coder_high claude-sonnet medium' > "$R"
check "effort: wrong effort is a mismatch" "$(run_one "$R" "$QA_HIGH")" "MISMATCH" \
  "an agent inheriting the lead effort is exactly what the roster is for"

# 6. An unknown scope belongs to neither harness.
R="$FIXTURES/r-otherscope"
printf '%s\n' 'gemini:advisor claude-fable medium' > "$R"
check "scope: an unrelated harness scope is ignored here" "$(run_one "$R" "$ADVISOR")" "" \
  "only claude: and bare rows apply to the claude verifier"

# 7. Case in the scope should not matter.
R="$FIXTURES/r-case"
printf '%s\n' 'CLAUDE:advisor gpt-6-astra medium' > "$R"
check "scope: matching is case-insensitive" "$(run_one "$R" "$ADVISOR")" "MISMATCH" \
  "a roster is hand-written -- casing must not silently disable a rule"

# 8. Bare rows are shared on purpose, and that is a sharp edge worth pinning:
#    the pre-existing roster row is bare, so it still reaches the Claude verifier
#    after this change. Migrating the roster is the other half of the fix.
R="$FIXTURES/r-bare-advisor"
printf '%s\n' 'advisor gpt-6-astra medium' > "$R"
check "bare: an unscoped advisor row still reaches the claude stage" "$(run_one "$R" "$ADVISOR")" "MISMATCH" \
  "documents why the roster must be migrated, not just the code merged"

printf '\nResults: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
