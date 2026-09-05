#!/bin/bash
# bash-read-guard: blocks a bare `cat|head|tail|less|more|bat` on a large file
# so it gets grepped, bulk-read, delegated, or dumped in full deliberately.
# Same rationale as read-scope-guard.sh, closing the gap it leaves open: the
# Read tool is guarded, but Bash is a second, unguarded door to the same
# problem -- a full-file dump lands in the LEAD's transcript and is re-read
# as cache every turn for the rest of the session.
#
# Parsing is deliberately conservative: this only reads the command STRING
# (no shell execution), so anything with a pipe, redirection, compound
# command (&&, ;, $(), backticks), multiple file arguments, or a command it
# doesn't recognise passes straight through unexamined. It would rather miss
# a real dump than misfire on ambiguous input -- see hooks/claude/README.md
# "Limits" for what that leaves open (e.g. a wrapper script that cats
# internally).
#
# Wire: PreToolUse, matcher "Bash", settings.json.
# Threshold: RELAY_MIN_LINES (default 500), shared with read-scope-guard.sh.
# Fail-open: any parse failure, missing jq, or empty stdin exits 0 silently.
set +e

IN=$(cat)
[ -z "$IN" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

cmd=$(printf '%s' "$IN" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0

# Subagents are exempt -- same rationale as read-scope-guard.sh: their
# context is discarded on return, so a big dump there costs once.
[ -n "$(printf '%s' "$IN" | jq -r '.agent_id // empty' 2>/dev/null)" ] && exit 0

# A pipe or redirection means this isn't a bare dump into the transcript --
# it's being filtered or sent to a file. Pass through.
case "$cmd" in
  *"|"*|*">"*) exit 0 ;;
esac

# Compound commands (&&, ;, command substitution) are out of scope for a
# "single file argument" guard -- pass through rather than guess which part
# of the command is the read.
case "$cmd" in
  *"&&"*|*";"*|*'$('*|*'`'*) exit 0 ;;
esac

read -ra tokens <<< "$cmd"
[ "${#tokens[@]}" -eq 0 ] && exit 0

base=$(basename -- "${tokens[0]}" 2>/dev/null)
case "$base" in
  cat|head|tail|less|more|bat) : ;;
  *) exit 0 ;;
esac

# Walk the remaining args. An explicit count (-n N, -N, -c N) means the
# caller already scoped the read deliberately -- pass through. More than one
# non-flag argument means we can't confidently say which one is "the file"
# -- pass through rather than guess.
explicit_count=0
file=""
multi=0
i=1
n=${#tokens[@]}
while [ "$i" -lt "$n" ]; do
  t="${tokens[$i]}"
  case "$t" in
    -n)
      i=$((i + 1))
      explicit_count=1
      ;;
    -n*|-c|-c*|-[0-9]*)
      explicit_count=1
      ;;
    -*)
      : # unrecognised flag -- ignore, don't try to be clever
      ;;
    *)
      if [ -z "$file" ]; then
        file="$t"
      else
        multi=1
      fi
      ;;
  esac
  i=$((i + 1))
done

[ "$explicit_count" -eq 1 ] && exit 0
[ "$multi" -eq 1 ] && exit 0
[ -z "$file" ] && exit 0

# Strip a layer of surrounding quotes the naive tokenizer may have left.
file="${file%\"}"; file="${file#\"}"
file="${file%\'}"; file="${file#\'}"

[ -f "$file" ] || exit 0

ext=$(printf '%s' "${file##*.}" | tr '[:upper:]' '[:lower:]')
case "$ext" in
  png|jpg|jpeg|gif|webp|ico|bmp|svg|pdf|ipynb|woff|woff2|ttf|otf|eot|mp3|mp4|mov|webm|zip|gz|tar|jar) exit 0 ;;
esac

lines=$(wc -l < "$file" 2>/dev/null | tr -d '[:space:]')
case "$lines" in ''|*[!0-9]*) exit 0 ;; esac

threshold="${RELAY_MIN_LINES:-500}"
case "$threshold" in ''|*[!0-9]*) threshold=500 ;; esac

if [ "$lines" -gt "$threshold" ]; then
  jq -n --arg f "$file" --arg n "$lines" --arg b "$base" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:("bash-read-guard: `" + $b + " " + $f + "` would dump " + $n + " lines straight into the transcript, re-read as cache every turn. Pick one: (a) grep for the section you need, or re-run with an explicit scope (`head -n N`, `tail -n N`, `sed -n`), (b) run `bin/bulk-read --question \"...\" --paths " + $f + "` and read only its answer, (c) delegate the file to the `runner`/scout role and keep only its brief, or (d) if you genuinely need it all inline, pipe or redirect it (e.g. `" + $b + " " + $f + " | less`) -- a pipe or redirect always passes this guard, which is what makes it a deliberate choice.")}}'
  exit 0
fi
exit 0
