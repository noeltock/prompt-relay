#!/usr/bin/env bash
# Deterministic evals for verify/wait-on-liveness.sh.
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
cleanup() { [ -n "${FIXTURES:-}" ] && [ -d "$FIXTURES" ] || return 0; rm -rf "$FIXTURES"; }
trap cleanup EXIT

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

run_wait() {  # seq_lines... -> prints "exit|stdout"
  : > "$CURSOR"
  printf '%s\n' "$@" > "$SEQ"
  local out ec
  out="$(SEQ="$SEQ" CURSOR="$CURSOR" CODEX_COMPANION="$STUB" \
         bash "$WAIT" --latest --budget "${BUDGET:-3}" --stall "${STALL:-2}" --interval 1 2>/dev/null)"
  ec=$?
  printf '%s|%s' "$ec" "$(printf '%s' "$out" | head -1 | cut -f1)"
}

running() {  # id updatedAt -> a status payload with one running job
  jq -cn --arg id "$1" --arg u "$2" \
    '{running:[{id:$id,kind:"task",createdAt:"2026-09-18T01:00:00.000Z",updatedAt:$u}]}'
}
idle() { printf '%s' '{"running":[]}'; }

pass=0; fail=0
check() {
  local name="$1" got="$2" want="$3" why="$4"
  if [ "$got" = "$want" ]; then printf 'PASS  %-46s %s\n' "$name" "$got"; pass=$((pass+1))
  else printf 'FAIL  %-46s got %s, wanted %s :: %s\n' "$name" "$got" "$want" "$why"; fail=$((fail+1)); fi
}

# 1. A job that keeps taking turns and then disappears from running[] is finished.
check "finishes when the job leaves running[]" \
  "$(run_wait "$(running j1 2026-09-18T01:00:01Z)" "$(running j1 2026-09-18T01:00:02Z)" "$(idle)")" \
  "0|finished" "the ordinary success path"

# 2. THE CASE THAT MOTIVATED THIS. updatedAt keeps advancing past the budget.
#    Under the old design a fixed timeout killed exactly this job for being slow.
BUDGET=2 check_job="$(run_wait \
  "$(running j2 2026-09-18T01:00:01Z)" "$(running j2 2026-09-18T01:00:02Z)" \
  "$(running j2 2026-09-18T01:00:03Z)" "$(running j2 2026-09-18T01:00:04Z)")"
check "a live job past budget says call again, not dead" "$check_job" \
  "2|running" "a slow job and a wedged job must not share an exit code"

# 3. updatedAt frozen for the whole stall window is a wedge.
STALL=2 BUDGET=9 check_stall="$(run_wait \
  "$(running j3 2026-09-18T01:00:01Z)" "$(running j3 2026-09-18T01:00:01Z)" \
  "$(running j3 2026-09-18T01:00:01Z)" "$(running j3 2026-09-18T01:00:01Z)" \
  "$(running j3 2026-09-18T01:00:01Z)" "$(running j3 2026-09-18T01:00:01Z)")"
check "frozen updatedAt is reported as stalled" "$check_stall" \
  "3|stalled" "the whole point: detect a wedge by silence, not by duration"

# 4. Nothing running at all, from the first poll, is not a stall.
check "no matching job exits 4, not 3" \
  "$(run_wait "$(idle)" "$(idle)" "$(idle)")" \
  "4|" "a wrong id must not look like a hang"

# 5. LOAD-BEARING NEGATIVE. A transient status failure mid-run must not be read
#    as either finished or stalled while turns are still advancing around it.
check "a single bad status reply is not a verdict" \
  "$(run_wait "$(running j5 2026-09-18T01:00:01Z)" "INVALID" "$(running j5 2026-09-18T01:00:02Z)" "$(idle)")" \
  "0|finished" "status flaking must not kill a healthy job"

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

printf '\nResults: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
