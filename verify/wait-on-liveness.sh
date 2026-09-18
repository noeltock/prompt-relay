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
#   1  usage or environment error -- including "the status call is not working"
#      and "state could not be written". Neither is a statement about the job.
#
# Three things this deliberately does NOT treat as a verdict:
#   - A status call we cannot make. Absent status is absent information: it says
#     nothing about whether the job finished, stalled, or never existed, so it
#     can never produce 0, 3 or 4. Persistent unavailability exits 1.
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
MISSES=2        # consecutive ABSENT polls before believing a job has finished
STATE_DIR="${LIVENESS_STATE_DIR:-${TMPDIR:-/tmp}/wait-on-liveness}"

usage() { sed -n '2,40p' "$0" >&2; exit 1; }

# `--id` with nothing after it used to leave $# unchanged and spin forever.
need_value() { [ $# -ge 2 ] || { printf 'wait-on-liveness: %s needs a value\n' "$1" >&2; exit 1; }; }

while [ $# -gt 0 ]; do
  case "$1" in
    --id)        need_value "$@"; JOB_ID="$2"; shift 2 ;;
    --latest)    LATEST=1; shift ;;
    --budget)    need_value "$@"; BUDGET="$2"; shift 2 ;;
    --stall)     need_value "$@"; STALL="$2"; shift 2 ;;
    --interval)  need_value "$@"; INTERVAL="$2"; shift 2 ;;
    --misses)    need_value "$@"; MISSES="$2"; shift 2 ;;
    --state-dir) need_value "$@"; STATE_DIR="$2"; shift 2 ;;
    -h|--help)   usage ;;
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

# One poll, with a THREE-way result, because two of those states were previously
# collapsed into "no output" and read as progress toward completion:
#   "<id>\t<updatedAt>"  the tracked job is running
#   ""                   a valid status reply that does not list the job: absent
#   "UNAVAILABLE"        the status call failed or returned non-JSON
# Only `absent` counts toward --misses. A status call we could not make tells us
# nothing about the job, so it must never accumulate toward "finished", however
# many times in a row it happens.
poll() {
  local out
  out="$(node "$COMPANION" status --all --json 2>/dev/null)" || { printf 'UNAVAILABLE'; return 0; }
  printf '%s' "$out" | jq -e . >/dev/null 2>&1 || { printf 'UNAVAILABLE'; return 0; }
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
unavailable=0
last_poll_ok=1

# Liveness state must OUTLIVE one invocation. --budget (480s) is deliberately
# below --stall (600s) so a call always returns inside the harness ceiling, which
# means a stall can never be detected within a single call: each retry restarted
# the clock and a wedged job stayed "running" forever. The last observed turn is
# therefore persisted per job id and reloaded on the next call.
state_file=''
load_state() {
  [ -n "$tracked" ] || return 0
  state_file="$STATE_DIR/$(printf '%s' "$tracked" | tr -c 'A-Za-z0-9._-' '_').state"
  [ -f "$state_file" ] || return 0
  local f_upd f_when
  IFS='	' read -r f_upd f_when < "$state_file" || return 0
  case "$f_when" in ''|*[!0-9]*) return 0 ;; esac
  last_seen="$f_upd"
  last_change="$f_when"
}
# A silent failure here is the stall bug coming back: the caller is told to poll
# again, the next call finds no state, and the clock restarts forever. So this
# aborts rather than returning a verdict it cannot support.
save_state() {
  [ -n "$tracked" ] || return 0
  if ! mkdir -p "$STATE_DIR" 2>/dev/null || [ ! -d "$STATE_DIR" ]; then
    printf 'wait-on-liveness: state dir is not usable: %s\n' "$STATE_DIR" >&2
    printf 'wait-on-liveness: without persisted state a stall can never be detected across calls.\n' >&2
    exit 1
  fi
  state_file="$STATE_DIR/$(printf '%s' "$tracked" | tr -c 'A-Za-z0-9._-' '_').state"
  if ! printf '%s\t%s\n' "$last_seen" "$last_change" > "$state_file" 2>/dev/null; then
    printf 'wait-on-liveness: could not write state: %s\n' "$state_file" >&2
    exit 1
  fi
}
clear_state() { [ -n "${state_file:-}" ] && [ -f "$state_file" ] && mv -f "$state_file" "$state_file.done" 2>/dev/null; return 0; }

load_state

while :; do
  row="$(poll)"

  if [ "$row" = "UNAVAILABLE" ]; then
    # Tells us nothing. Do not touch misses, do not touch last_change, and
    # record that the most recent observation is not an observation at all.
    unavailable=$(( unavailable + 1 ))
    last_poll_ok=0
  elif [ -n "$row" ]; then
    last_poll_ok=1
    id="${row%%	*}"
    upd="${row#*	}"
    if [ -z "$tracked" ]; then
      # First sighting under --latest: latch onto this id and follow only it.
      # Without this, a second job starting would quietly become the thing being
      # waited on while the output still named the first.
      tracked="$id"
      JOB_ID="$id"
      load_state
    fi
    seen_once=1
    misses=0
    if [ "$upd" != "$last_seen" ]; then
      last_seen="$upd"
      last_change="$(date +%s)"
    fi
  else
    last_poll_ok=1
    if [ "$seen_once" -eq 1 ]; then
    misses=$(( misses + 1 ))
    if [ "$misses" -ge "$MISSES" ]; then
      clear_state
      printf 'finished\t%s\n' "${tracked:-?}"
      exit 0
    fi
    fi
  fi

  # Absent status is absent information. Once the status call has failed for a
  # whole stall window we stop waiting, but we report the environment, not the
  # job: "no such job" and "stalled" are both claims we are in no position to
  # make while we cannot see the job at all.
  if [ "$last_poll_ok" -eq 0 ] && [ $(( unavailable * INTERVAL )) -ge "$STALL" ]; then
    printf 'wait-on-liveness: status has been unavailable for %ds; no verdict about %s\n' \
      "$(( unavailable * INTERVAL ))" "${tracked:-(latest)}" >&2
    exit 1
  fi

  now="$(date +%s)"

  if [ "$seen_once" -eq 0 ] && [ "$last_poll_ok" -eq 1 ] && [ $(( now - started )) -ge "$INTERVAL" ]; then
    printf 'wait-on-liveness: no running job matched %s\n' "${JOB_ID:-(latest)}" >&2
    exit 4
  fi

  if [ "$seen_once" -eq 1 ] && [ "$last_poll_ok" -eq 1 ] && [ $(( now - last_change )) -ge "$STALL" ]; then
    clear_state
    printf 'stalled\t%s\t%ds without a turn\n' "${tracked:-?}" "$(( now - last_change ))"
    exit 3
  fi

  if [ $(( now - started )) -ge "$BUDGET" ]; then
    save_state
    printf 'running\t%s\tlast turn %ds ago, call again\n' "${tracked:-?}" "$(( now - last_change ))"
    exit 2
  fi

  sleep "$INTERVAL"
done
