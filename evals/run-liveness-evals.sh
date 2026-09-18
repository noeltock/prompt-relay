#!/usr/bin/env bash
# Deterministic evals for wait-on-liveness.sh.
#
# Every case drives a STUB companion, so no model runs and no Codex is needed.
# The stub reads a scripted sequence of status payloads from a file, one JSON
# document per line, and emits the next one on each call. That is what lets a
# test script "time" without waiting: --interval 1 plus a four-line script is a
# four-second run covering what would otherwise be minutes.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAIT="$SCRIPT_DIR/../verify/wait-on-liveness.sh"

command -v jq >/dev/null 2>&1 || { printf 'wait-on-liveness.evals: jq is required\n' >&2; exit 1; }

FIXTURES="$(mktemp -d -t wait-on-liveness-evals.XXXXXX)" || {
  printf 'wait-on-liveness.evals: mktemp -d failed, refusing to run\n' >&2; exit 1
}
case "$FIXTURES" in
  /*) [ -d "$FIXTURES" ] || { printf 'wait-on-liveness.evals: fixture dir is not a directory\n' >&2; exit 1; } ;;
  *)  printf 'wait-on-liveness.evals: refusing a non-absolute fixture dir\n' >&2; exit 1 ;;
esac
# Recoverable cleanup: move aside, never rm -rf. A fixture path is computed, and
# a computed path that is wrong once is unrecoverable with rm.
cleanup() {
  [ -n "${FIXTURES:-}" ] && [ -d "$FIXTURES" ] || return 0
  if command -v trash >/dev/null 2>&1; then
    trash "$FIXTURES" 2>/dev/null
  else
    mkdir -p "$HOME/.Trash" 2>/dev/null
    mv "$FIXTURES" "$HOME/.Trash/wait-on-liveness-evals-$(date +%s)" 2>/dev/null
  fi
}
trap cleanup EXIT

STATE="$FIXTURES/state"
STUB="$FIXTURES/companion.mjs"
SEQ="$FIXTURES/seq.jsonl"
CURSOR="$FIXTURES/cursor"

# The stub ignores its arguments and returns line N of $SEQ on call N, holding
# the last line once exhausted, so a poll loop can run longer than the script.
cat > "$STUB" <<'STUBEOF'
import fs from 'node:fs';
const seq = process.env.SEQ, cur = process.env.CURSOR;
const lines = fs.readFileSync(seq, 'utf8').split('\n').filter(Boolean);
let i = 0;
try { i = parseInt(fs.readFileSync(cur, 'utf8'), 10) || 0; } catch {}
const out = lines[Math.min(i, lines.length - 1)];
fs.writeFileSync(cur, String(i + 1));
process.stdout.write(out === 'INVALID' ? 'not json at all' : out);
STUBEOF

# BUDGET discipline. Each poll costs one --interval plus a node start, so
# elapsed time runs ahead of poll count. Any case whose expected answer is
# terminal (0, 3 or 4) must set a budget comfortably clear of its poll count,
# or it races the budget and passes on timing rather than on behaviour. Only a
# case that EXPECTS exit 2 should sit near the boundary.
run_wait() {  # budget stall seq_lines... -> prints "exit|stdout"
  # Budget and stall are POSITIONAL, not environment. An earlier version set
  # them as `BUDGET=2 check ... "$(run_wait ...)"`, which does not work twice
  # over: a var prefixed to `check` is not in scope for the command
  # substitution, which expands first, and `BUDGET=2 x="$(...)"` is a plain
  # assignment that leaks to every later case. The suite passed or failed on
  # case order.
  local budget="$1" stall="$2"; shift 2
  : > "$CURSOR"
  printf '%s\n' "$@" > "$SEQ"
  local out ec
  out="$(SEQ="$SEQ" CURSOR="$CURSOR" CODEX_COMPANION="$STUB" \
         LIVENESS_STATE_DIR="$STATE" \
         bash "$WAIT" --latest --budget "$budget" --stall "$stall" --interval 1 2>/dev/null)"
  ec=$?
  printf '%s|%s' "$ec" "$(printf '%s' "$out" | head -1 | cut -f1)"
}

running() {  # id updatedAt -> a status payload with one running job
  jq -cn --arg id "$1" --arg u "$2" \
    '{running:[{id:$id,kind:"task",createdAt:"2026-09-18T01:00:00.000Z",updatedAt:$u}]}'
}
idle() { printf '%s' '{"running":[]}'; }

# Run the SAME job across several calls without resetting the fixture cursor or
# the state dir. This is the only way to exercise anything that must survive an
# invocation, and --budget is deliberately below --stall, so a stall is only ever
# reachable across calls.
run_calls() {  # n budget stall id seq_lines... -> prints the last "exit|stdout"
  local n="$1" budget="$2" stall="$3" id="$4"; shift 4
  : > "$CURSOR"
  printf '%s\n' "$@" > "$SEQ"
  local out ec i=0
  while [ "$i" -lt "$n" ]; do
    out="$(SEQ="$SEQ" CURSOR="$CURSOR" CODEX_COMPANION="$STUB" LIVENESS_STATE_DIR="$STATE" \
           bash "$WAIT" --id "$id" --budget "$budget" --stall "$stall" --interval 1 2>/dev/null)"
    ec=$?
    i=$(( i + 1 ))
  done
  printf '%s|%s' "$ec" "$(printf '%s' "$out" | head -1 | cut -f1)"
}

pass=0; fail=0
check() {
  local name="$1" got="$2" want="$3" why="$4"
  if [ "$got" = "$want" ]; then printf 'PASS  %-46s %s\n' "$name" "$got"; pass=$((pass+1))
  else printf 'FAIL  %-46s got %s, wanted %s :: %s\n' "$name" "$got" "$want" "$why"; fail=$((fail+1)); fi
}

# 1. A job that keeps taking turns and then disappears from running[] is finished.
#    Two idle polls, not one: --misses defaults to 2, so a single empty reply is
#    deliberately not a verdict. A one-idle fixture here would pass or fail on
#    timing rather than on behaviour.
check "finishes when the job leaves running[]" \
  "$(run_wait 20 20 "$(running j1 2026-09-18T01:00:01Z)" "$(running j1 2026-09-18T01:00:02Z)" "$(idle)" "$(idle)")" \
  "0|finished" "the ordinary success path"

# 2. THE CASE THAT MOTIVATED THIS. updatedAt keeps advancing past the budget.
#    Under the old design a fixed timeout killed exactly this job for being slow.
check_job="$(run_wait 2 20 \
  "$(running j2 2026-09-18T01:00:01Z)" "$(running j2 2026-09-18T01:00:02Z)" \
  "$(running j2 2026-09-18T01:00:03Z)" "$(running j2 2026-09-18T01:00:04Z)")"
check "a live job past budget says call again, not dead" "$check_job" \
  "2|running" "a slow job and a wedged job must not share an exit code"

# 3. updatedAt frozen for the whole stall window is a wedge.
check_stall="$(run_wait 30 2 \
  "$(running j3 2026-09-18T01:00:01Z)" "$(running j3 2026-09-18T01:00:01Z)" \
  "$(running j3 2026-09-18T01:00:01Z)" "$(running j3 2026-09-18T01:00:01Z)" \
  "$(running j3 2026-09-18T01:00:01Z)" "$(running j3 2026-09-18T01:00:01Z)")"
check "frozen updatedAt is reported as stalled" "$check_stall" \
  "3|stalled" "the whole point: detect a wedge by silence, not by duration"

# 4. Nothing running at all, from the first poll, is not a stall.
check "no matching job exits 4, not 3" \
  "$(run_wait 20 20 "$(idle)" "$(idle)" "$(idle)")" \
  "4|" "a wrong id must not look like a hang"

# 5. LOAD-BEARING NEGATIVE. A transient status failure mid-run must not be read
#    as finished. Asserting the final outcome here would be INERT: the sequence
#    ends idle either way, so a script that quits at the bad reply and one that
#    rides through it both report "finished". The run must therefore end while
#    the job is still alive, so a premature exit shows up as a different code.
check_flake="$(run_wait 4 20 \
  "$(running j5 2026-09-18T01:00:01Z)" "INVALID" "$(running j5 2026-09-18T01:00:02Z)" \
  "$(running j5 2026-09-18T01:00:03Z)" "$(running j5 2026-09-18T01:00:04Z)")"
check "a single bad status reply is not a verdict" "$check_flake" \
  "2|running" "one flaky status call reads exactly like a job leaving running[]"

# 5b. Two consecutive empties ARE a finish: the tolerance must not become a hang.
check "consecutive empties do mean finished" \
  "$(run_wait 20 20 "$(running j5b 2026-09-18T01:00:01Z)" "$(idle)" "$(idle)" "$(idle)")" \
  "0|finished" "--misses adds tolerance, it must not remove the success path"

# 5c. A second job appearing must not become the thing being waited on. Under
#     --latest the first sighting latches an id; when THAT id leaves running[],
#     the answer is finished, regardless of what else started meanwhile.
check "--latest follows the job it latched, not the newest" \
  "$(run_wait 20 20 "$(running first 2026-09-18T01:00:01Z)" "$(running second 2026-09-18T01:00:02Z)" \
              "$(running second 2026-09-18T01:00:03Z)" "$(running second 2026-09-18T01:00:04Z)")" \
  "0|finished" "waiting on the wrong job while printing the right name is the worst outcome"

# 6. A specific --id that is not the running job must not silently latch onto it.
: > "$CURSOR"
printf '%s\n' "$(running other 2026-09-18T01:00:01Z)" "$(running other 2026-09-18T01:00:02Z)" > "$SEQ"
out="$(SEQ="$SEQ" CURSOR="$CURSOR" CODEX_COMPANION="$STUB" \
       bash "$WAIT" --id nosuch --budget 3 --stall 2 --interval 1 2>/dev/null)"; ec=$?
check "--id only matches that id" "$ec|$(printf '%s' "$out" | cut -f1)" "4|" \
  "waiting on the wrong job is worse than not waiting"

# 7. Usage errors are distinguishable from job outcomes.
SEQ="$SEQ" CURSOR="$CURSOR" CODEX_COMPANION="$STUB" bash "$WAIT" >/dev/null 2>&1
check "no --id and no --latest is a usage error" "$?|" "1|" "exit 1 is reserved for caller error"

SEQ="$SEQ" CURSOR="$CURSOR" CODEX_COMPANION="$STUB" bash "$WAIT" --latest --budget abc >/dev/null 2>&1
check "non-numeric budget is a usage error" "$?|" "1|" "a typo must not become a zero-second budget"

# 8. STATUS UNAVAILABLE IS NOT PROGRESS TOWARDS FINISHED. Two consecutive failed
#    fetches used to satisfy --misses and report a live job as finished. A call
#    we could not make says nothing about the job, however many times it fails.
check "consecutive failed fetches are not a finish" \
  "$(run_wait 6 30 "$(running j8 2026-09-18T01:00:01Z)" "INVALID" "INVALID" \
                   "$(running j8 2026-09-18T01:00:02Z)" "$(running j8 2026-09-18T01:00:03Z)")" \
  "2|running" "unavailable status must be distinct from an absent job"

# 9. THE CROSS-CALL CASE. --budget sits below --stall by design, so a stall can
#    never be reached inside one call: without persisted state every retry reset
#    the clock and a wedged job reported "running" forever.
check "a stall accumulates across calls" \
  "$(run_calls 3 3 7 j9 "$(running j9 frozen)")" \
  "3|stalled" "the regression that made the stall threshold unreachable"

# 9b. And the same state must not turn a healthy job into a false stall.
check "advancing turns across calls do not stall" \
  "$(run_calls 2 2 30 j9b "$(running j9b 2026-09-18T01:00:01Z)" "$(running j9b 2026-09-18T01:00:02Z)" \
                         "$(running j9b 2026-09-18T01:00:03Z)" "$(running j9b 2026-09-18T01:00:04Z)")" \
  "2|running" "persistence must carry liveness, not just decay"

# 10. A flag that takes a value must be given one, rather than spinning.
timeout 10 bash "$WAIT" --id >/dev/null 2>&1
check "--id with no value is a usage error" "$?|" "1|" "it used to loop forever on a missing value"

printf '\nResults: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
