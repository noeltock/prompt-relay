#!/usr/bin/env bash
# wait-on-liveness.sh — wait on a Codex job by liveness, not by wall clock.
#
# A timeout is a deadline, and a deadline answers the wrong question. A job that
# takes twelve minutes is not a job that has failed, but a wall-clock limit
# cannot tell the two apart, so it kills slow work and teaches agents to route
# around the block that killed it.
#
# The companion already reports the right signal. Every job carries an
# `updatedAt` that advances on each turn: moving means alive at any duration,
# frozen means wedged. This polls that.
#
# It is also the pattern to copy for another vendor. Nothing here is specific to
# Codex except the two jq expressions that locate `running[]` and `updatedAt`.
#
# Exit codes, which are the interface:
#   0  job finished           -- stop waiting, read the result
#   2  still running, budget spent, and updatedAt IS advancing
#                             -- call again; this is the resumable case that
#                                makes a long job survive a short Bash ceiling
#   3  stalled                -- updatedAt frozen past --stall; cancel it
#   4  no such job            -- wrong id, or it finished before the first poll
#   1  usage or environment error
#
# Two things this deliberately does NOT treat as a verdict:
#   - A single status call that fails or returns junk. It takes --misses
#     consecutive empty polls to call a job finished, because one flaky reply
#     otherwise reads exactly like a job that has left running[].
#   - Another job starting. --latest picks the newest running job on the FIRST
#     sighting and then follows that id, so a second job cannot silently become
#     the thing being waited on.
#
# Usage:
#   wait-on-liveness.sh --latest
#   wait-on-liveness.sh --id review-mu6ar1cm-x8usuo --budget 480 --stall 300
#
# CODEX_COMPANION overrides companion discovery (the eval suite sets it).
set -u

JOB_ID=''
LATEST=0
BUDGET=480      # under the 600s Bash tool ceiling, so a call always returns
STALL=600       # updatedAt frozen this long => wedged. Must exceed the longest
                # single turn you expect, or a slow turn reads as a hang: the
                # signal is per-turn, so a job mid-turn is legitimately quiet.
INTERVAL=15
MISSES=2        # consecutive empty polls before believing a job has finished

usage() { sed -n '2,40p' "$0" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --id)       JOB_ID="${2:-}"; shift 2 ;;
    --latest)   LATEST=1; shift ;;
    --budget)   BUDGET="${2:-}"; shift 2 ;;
    --stall)    STALL="${2:-}"; shift 2 ;;
    --interval) INTERVAL="${2:-}"; shift 2 ;;
    --misses)   MISSES="${2:-}"; shift 2 ;;
    -h|--help)  usage ;;
    *) printf 'wait-on-liveness: unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

[ -n "$JOB_ID" ] || [ "$LATEST" -eq 1 ] || { printf 'wait-on-liveness: pass --id ID or --latest\n' >&2; exit 1; }

case "$BUDGET$STALL$INTERVAL$MISSES" in
  *[!0-9]*) printf 'wait-on-liveness: --budget, --stall, --interval and --misses must be whole numbers\n' >&2; exit 1 ;;
esac
[ "$INTERVAL" -gt 0 ] || { printf 'wait-on-liveness: --interval must be positive\n' >&2; exit 1; }
[ "$MISSES" -gt 0 ] || { printf 'wait-on-liveness: --misses must be positive\n' >&2; exit 1; }

command -v jq >/dev/null 2>&1 || { printf 'wait-on-liveness: jq is required\n' >&2; exit 1; }

COMPANION="${CODEX_COMPANION:-$(ls -1d "$HOME"/.claude/plugins/cache/openai-codex/codex/*/scripts/codex-companion.mjs 2>/dev/null | sort -V | tail -1)}"
[ -n "$COMPANION" ] || { printf 'wait-on-liveness: no codex companion found\n' >&2; exit 1; }

# One poll. Emits "<id>\t<updatedAt>" for the tracked job, or nothing if it is
# not in running[]. A status call that fails or returns non-JSON also emits
# nothing, so an empty result is ambiguous by construction: it means EITHER the
# job finished OR the status call flaked. The caller resolves that by requiring
# --misses consecutive empties, never by acting on one.
poll() {
  local out
  out="$(node "$COMPANION" status --all --json 2>/dev/null)" || return 0
  printf '%s' "$out" | jq -e . >/dev/null 2>&1 || return 0
  if [ -n "$JOB_ID" ]; then
    printf '%s' "$out" | jq -r --arg id "$JOB_ID" \
      '(.running // [])[] | select(.id == $id) | "\(.id)\t\(.updatedAt // "")"'
  else
    printf '%s' "$out" | jq -r \
      '(.running // []) | sort_by(.createdAt) | last | select(. != null) | "\(.id)\t\(.updatedAt // "")"'
  fi
}

started="$(date +%s)"
last_seen=''        # last observed updatedAt
last_change="$started"
tracked="$JOB_ID"
seen_once=0
misses=0

while :; do
  row="$(poll)"

  if [ -n "$row" ]; then
    id="${row%%	*}"
    upd="${row#*	}"
    if [ -z "$tracked" ]; then
      # First sighting under --latest: latch onto this id and follow only it.
      # Without this, a second job starting would quietly become the thing being
      # waited on while the output still named the first.
      tracked="$id"
      JOB_ID="$id"
    fi
    seen_once=1
    misses=0
    if [ "$upd" != "$last_seen" ]; then
      last_seen="$upd"
      last_change="$(date +%s)"
    fi
  elif [ "$seen_once" -eq 1 ]; then
    misses=$(( misses + 1 ))
    if [ "$misses" -ge "$MISSES" ]; then
      printf 'finished\t%s\n' "${tracked:-?}"
      exit 0
    fi
  fi

  now="$(date +%s)"

  if [ "$seen_once" -eq 0 ] && [ $(( now - started )) -ge "$INTERVAL" ]; then
    printf 'wait-on-liveness: no running job matched %s\n' "${JOB_ID:-(latest)}" >&2
    exit 4
  fi

  if [ "$seen_once" -eq 1 ] && [ $(( now - last_change )) -ge "$STALL" ]; then
    printf 'stalled\t%s\t%ds without a turn\n' "${tracked:-?}" "$(( now - last_change ))"
    exit 3
  fi

  if [ $(( now - started )) -ge "$BUDGET" ]; then
    printf 'running\t%s\tlast turn %ds ago, call again\n' "${tracked:-?}" "$(( now - last_change ))"
    exit 2
  fi

  sleep "$INTERVAL"
done
