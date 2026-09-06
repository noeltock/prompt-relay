#!/bin/bash
# read-scope-guard: blocks unscoped Read calls on large text files so they get
# scoped (offset/limit), bulk-read, delegated, or read in full deliberately.
# Deterministic backstop for scout-first context discipline: a large inline
# Read sits in the LEAD's transcript and is re-billed as cache on every later
# turn of the session, so the one-time cost of reading it compounds for as
# long as the session runs.
#
# Wire: PreToolUse, matcher "Read", settings.json.
# Threshold: RELAY_MIN_LINES (default 500).
# Fail-open: any parse failure, missing jq, or empty stdin exits 0 silently.
set +e

IN=$(cat)
[ -z "$IN" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

f=$(printf '%s' "$IN" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
lim=$(printf '%s' "$IN" | jq -r '.tool_input.limit // empty' 2>/dev/null)
off=$(printf '%s' "$IN" | jq -r '.tool_input.offset // empty' 2>/dev/null)

# Subagents are exempt. The rationale above ("re-billed as cache on every later
# turn") is a property of the LEAD's transcript; a subagent's context is discarded
# when it returns, so a big read there costs once and is the whole point of
# delegating. Enforcing uniformly also makes the guard's own advice circular --
# it tells you to delegate the file, then denies the delegate.
# agent_id is present on subagent hook payloads and absent on the lead's.
[ -n "$(printf '%s' "$IN" | jq -r '.agent_id // empty' 2>/dev/null)" ] && exit 0

# Allow scoped reads and anything that is not a regular file.
[ -z "$f" ] && exit 0
[ -n "$lim" ] && exit 0
[ -n "$off" ] && exit 0
[ -f "$f" ] || exit 0

# Exempt binary/media formats (Read renders these; line count is meaningless).
ext=$(printf '%s' "${f##*.}" | tr '[:upper:]' '[:lower:]')
case "$ext" in
  png|jpg|jpeg|gif|webp|ico|bmp|svg|pdf|ipynb|woff|woff2|ttf|otf|eot|mp3|mp4|mov|webm|zip|gz|tar|jar) exit 0 ;;
esac

lines=$(wc -l < "$f" 2>/dev/null | tr -d '[:space:]')
case "$lines" in ''|*[!0-9]*) exit 0 ;; esac

threshold="${RELAY_MIN_LINES:-500}"
case "$threshold" in ''|*[!0-9]*) threshold=500 ;; esac

if [ "$lines" -gt "$threshold" ]; then
  jq -n --arg f "$f" --arg n "$lines" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:("read-scope-guard: " + $f + " is " + $n + " lines. An unscoped Read this large sits in the transcript and is re-read as cache every turn. Pick one: (a) grep for the section you need and re-issue Read with offset+limit, (b) run `bulk-read --question \"...\" --paths " + $f + "` and read only its answer, (c) delegate the file to the `runner`/scout role and keep only its brief, or (d) if the full read is genuinely required, re-issue with an explicit limit (e.g. limit=" + $n + ") to make it a deliberate choice.")}}'
  exit 0
fi
exit 0
