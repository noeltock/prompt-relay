#!/usr/bin/env bash
# run-hook-evals.sh — deterministic eval for hooks/claude/*.sh.
# Feeds synthetic PreToolUse JSON straight to each hook and checks the
# decision. No live Claude Code session needed. Cases are documented in
# evals/hook-cases.md. PASS/FAIL per case; exits 1 if any case fails.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/../hooks/claude"
READ_HOOK="$HOOKS_DIR/read-scope-guard.sh"
BASH_HOOK="$HOOKS_DIR/bash-read-guard.sh"
SCOUT_HOOK="$HOOKS_DIR/scout-model-pin.sh"

for f in "$READ_HOOK" "$BASH_HOOK" "$SCOUT_HOOK"; do
  if [ ! -f "$f" ]; then
    echo "run-hook-evals: missing hook: $f" >&2
    exit 1
  fi
done

command -v jq >/dev/null 2>&1 || { echo "run-hook-evals: jq is required" >&2; exit 1; }

FIXTURES="$(mktemp -d -t hook-evals.XXXXXX)"
trap 'rm -rf "$FIXTURES"' EXIT

BIG="$FIXTURES/big.txt"
SMALL="$FIXTURES/small.txt"
PNG="$FIXTURES/image.png"

seq 1 600 > "$BIG"
seq 1 100 > "$SMALL"
printf '\x89PNG\r\n\032\n' > "$PNG"

pass=0
fail=0

check() {
  local name="$1" ok="$2" detail="$3"
  if [ "$ok" = "1" ]; then
    printf 'PASS  %s\n' "$name"
    pass=$((pass + 1))
  else
    printf 'FAIL  %s -- %s\n' "$name" "$detail"
    fail=$((fail + 1))
  fi
}

is_empty() { [ -z "$(printf '%s' "$1" | tr -d '[:space:]')" ]; }

decision_is() {
  printf '%s' "$1" | jq -e --arg d "$2" '.hookSpecificOutput.permissionDecision == $d' >/dev/null 2>&1
}

model_is() {
  printf '%s' "$1" | jq -e --arg m "$2" '.hookSpecificOutput.updatedInput.model == $m' >/dev/null 2>&1
}

# --- read-scope-guard.sh ---

out=$(jq -n --arg f "$BIG" '{tool_input:{file_path:$f}}' | bash "$READ_HOOK")
[ 1 = 1 ] && { decision_is "$out" "deny" && r=1 || r=0; }
check "read: large unscoped file -> deny" "$r" "got: $out"

out=$(jq -n --arg f "$BIG" '{tool_input:{file_path:$f, limit:100}}' | bash "$READ_HOOK")
is_empty "$out" && r=1 || r=0
check "read: scoped with limit -> allow" "$r" "got: $out"

out=$(jq -n --arg f "$BIG" '{tool_input:{file_path:$f, offset:10}}' | bash "$READ_HOOK")
is_empty "$out" && r=1 || r=0
check "read: scoped with offset -> allow" "$r" "got: $out"

out=$(jq -n --arg f "$SMALL" '{tool_input:{file_path:$f}}' | bash "$READ_HOOK")
is_empty "$out" && r=1 || r=0
check "read: small file -> allow" "$r" "got: $out"

out=$(jq -n --arg f "$PNG" '{tool_input:{file_path:$f}}' | bash "$READ_HOOK")
is_empty "$out" && r=1 || r=0
check "read: png -> allow" "$r" "got: $out"

out=$(jq -n --arg f "$BIG" '{tool_input:{file_path:$f}, agent_id:"sub-123"}' | bash "$READ_HOOK")
is_empty "$out" && r=1 || r=0
check "read: agent_id present -> allow" "$r" "got: $out"

out=$(jq -n --arg f "$BIG" '{tool_input:{file_path:$f}}' | RELAY_MIN_LINES=1000 bash "$READ_HOOK")
is_empty "$out" && r=1 || r=0
check "read: RELAY_MIN_LINES=1000, 600-line file -> allow" "$r" "got: $out"

# --- bash-read-guard.sh ---

out=$(jq -n --arg c "cat $BIG" '{tool_input:{command:$c}}' | bash "$BASH_HOOK")
decision_is "$out" "deny" && r=1 || r=0
check "bash: cat big -> deny" "$r" "got: $out"

out=$(jq -n --arg c "cat $BIG | grep x" '{tool_input:{command:$c}}' | bash "$BASH_HOOK")
is_empty "$out" && r=1 || r=0
check "bash: cat big | grep x -> allow" "$r" "got: $out"

out=$(jq -n --arg c "head -n 20 $BIG" '{tool_input:{command:$c}}' | bash "$BASH_HOOK")
is_empty "$out" && r=1 || r=0
check "bash: head -n 20 big -> allow" "$r" "got: $out"

out=$(jq -n --arg c "sed -n 1,50p $BIG" '{tool_input:{command:$c}}' | bash "$BASH_HOOK")
is_empty "$out" && r=1 || r=0
check "bash: sed -n 1,50p big -> allow" "$r" "got: $out"

out=$(jq -n --arg c "cat $SMALL" '{tool_input:{command:$c}}' | bash "$BASH_HOOK")
is_empty "$out" && r=1 || r=0
check "bash: cat small -> allow" "$r" "got: $out"

out=$(jq -n --arg c "cat $BIG" '{tool_input:{command:$c}, agent_id:"sub-123"}' | bash "$BASH_HOOK")
is_empty "$out" && r=1 || r=0
check "bash: agent_id present -> allow" "$r" "got: $out"

# --- scout-model-pin.sh ---

out=$(jq -n '{tool_input:{subagent_type:"Explore"}}' | bash "$SCOUT_HOOK")
model_is "$out" "sonnet" && r=1 || r=0
check "scout: Explore, no model -> pinned sonnet" "$r" "got: $out"

out=$(jq -n '{tool_input:{subagent_type:"Explore", model:"opus"}}' | bash "$SCOUT_HOOK")
is_empty "$out" && r=1 || r=0
check "scout: Explore, model already set -> unchanged" "$r" "got: $out"

out=$(jq -n '{tool_input:{subagent_type:"coder-low"}}' | bash "$SCOUT_HOOK")
is_empty "$out" && r=1 || r=0
check "scout: non-scout subagent_type -> unchanged" "$r" "got: $out"

out=$(jq -n '{tool_input:{subagent_type:"Explore"}}' | RELAY_SCOUT_MODEL=haiku bash "$SCOUT_HOOK")
model_is "$out" "haiku" && r=1 || r=0
check "scout: RELAY_SCOUT_MODEL=haiku honoured" "$r" "got: $out"

echo
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && exit 0
exit 1
