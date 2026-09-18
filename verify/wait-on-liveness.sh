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
# frozen means wedged within minutes. This polls that.
#
# It is also the pattern to copy for another vendor. Nothing here is specific to
# Codex except the two jq expressions that locate `running[]` and `updatedAt`.
#
# Exit codes, which are the interface:
#   0  job finished           -- stop waiting, read the result
#   2  still running, budget spent, and updatedAt IS advancing
#                             -- call again; this is the resumable case that
#                                makes a long job survive a short harness ceiling
#   3  stalled                -- updatedAt frozen past --stall; cancel it
#   4  no such job            -- wrong id, or it finished before the first poll
#   1  usage or environment error
#
# Usage:
#   verify/wait-on-liveness.sh --latest
#   verify/wait-on-liveness.sh --id review-abc123 --budget 480 --stall 300
#
# A file-mtime watchdog is a weaker substitute where no such timestamp exists:
# it is blind to a read-only job, which writes nothing and so looks identical to
# a hang.
#
# CODEX_COMPANION overrides companion discovery (the eval suite sets it).
set -u

JOB_ID=''
LATEST=0
BUDGET=480      # under the 600s Bash tool ceiling, so a call always returns
STALL=300       # updatedAt frozen this long => wedged
INTERVAL=15

usage() { sed -n '2,40p' "$0" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --id)       JOB_ID="${2:-}"; shift 2 ;;
    --latest)   LATEST=1; shift ;;
    --budget)   BUDGET="${2:-}"; shift 2 ;;
    --stall)    STALL="${2:-}"; shift 2 ;;
    --interval) INTERVAL="${2:-}"; shift 2 ;;
    -h|--help)  usage ;;
    *) printf 'codex-wait: unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

[ -n "$JOB_ID" ] || [ "$LATEST" -eq 1 ] || { printf 'codex-wait: pass --id ID or --latest\n' >&2; exit 1; }

case "$BUDGET$STALL$INTERVAL" in
  *[!0-9]*) printf 'codex-wait: --budget, --stall and --interval must be whole seconds\n' >&2; exit 1 ;;
esac
[ "$INTERVAL" -gt 0 ] || { printf 'codex-wait: --interval must be positive\n' >&2; exit 1; }

command -v jq >/dev/null 2>&1 || { printf 'codex-wait: jq is required\n' >&2; exit 1; }

COMPANION="${CODEX_COMPANION:-$(ls -1d "$HOME"/.claude/plugins/cache/openai-codex/codex/*/scripts/codex-companion.mjs 2>/dev/null | sort -V | tail -1)}"
[ -n "$COMPANION" ] || { printf 'codex-wait: no codex companion found\n' >&2; exit 1; }

# One poll. Emits "<id>\t<updatedAt>" for the tracked job, or nothing if it is
# not in running[]. A status call that fails or returns non-JSON emits nothing
# too, which is deliberately indistinguishable from "finished" for one poll --
# a transient failure must not be read as a stall, so only a frozen updatedAt
# across the whole --stall window ends the wait.
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

while :; do
  row="$(poll)"

  if [ -n "$row" ]; then
    seen_once=1
    id="${row%%	*}"
    upd="${row#*	}"
    [ -n "$tracked" ] || tracked="$id"
    if [ "$upd" != "$last_seen" ]; then
      last_seen="$upd"
      last_change="$(date +%s)"
    fi
  elif [ "$seen_once" -eq 1 ]; then
    # It was running and now is not: finished.
    printf 'finished\t%s\n' "${tracked:-?}"
    exit 0
  fi

  now="$(date +%s)"

  if [ "$seen_once" -eq 0 ] && [ $(( now - started )) -ge "$INTERVAL" ]; then
    printf 'codex-wait: no running job matched %s\n' "${JOB_ID:-(latest)}" >&2
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
