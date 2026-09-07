#!/usr/bin/env bash
# check-routing-codex.sh — verify the model and effort used by Codex delegates.
set -u

usage() {
  cat <<'EOF'
Usage: check-routing-codex.sh [--since N] [--after TIMESTAMP] [--json] [--roster FILE]
                              [--codex-home DIR] [--log FILE]

By default, reads subagent transcripts under ~/.codex/sessions and
~/.codex/archived_sessions. --log adds legacy hook or forwarder JSONL rows.
EOF
}

parse_after() {
  case "$1" in
    ''|*[!0-9]*) ;;
    *) printf '%s' "$1"; return 0 ;;
  esac
  date -d "$1" +%s 2>/dev/null && return 0
  date -j -f '%Y-%m-%dT%H:%M:%S' "$1" +%s 2>/dev/null && return 0
  date -j -f '%Y-%m-%d' "$1" +%s 2>/dev/null && return 0
  return 1
}

command -v jq >/dev/null 2>&1 || {
  printf '%s\n' 'jq is required.' >&2
  exit 2
}

since=7
after=''
after_set=0
json_output=0
roster=''
codex_home="${CODEX_HOME:-$HOME/.codex}"
extra_log=''

while [ "$#" -gt 0 ]; do
  case "$1" in
    --since)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      since="$2"
      shift 2
      ;;
    --after)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      after="$2"
      after_set=1
      shift 2
      ;;
    --json)
      json_output=1
      shift
      ;;
    --roster)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      roster="$2"
      shift 2
      ;;
    --codex-home)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      codex_home="$2"
      shift 2
      ;;
    --log)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      extra_log="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

case "$since" in
  ''|*[!0-9]*)
    printf '%s\n' '--since must be a non-negative whole number of days.' >&2
    exit 2
    ;;
esac

after_epoch=''
if [ "$after_set" -eq 1 ]; then
  if ! after_epoch="$(parse_after "$after")"; then
    printf '%s\n' '--after must be epoch seconds, YYYY-MM-DD, or YYYY-MM-DDTHH:MM:SS.' >&2
    exit 2
  fi
fi

if [ -n "$roster" ]; then
  if [ ! -f "$roster" ]; then
    printf 'Roster file not found: %s\n' "$roster" >&2
    exit 2
  fi
elif [ -f './.prompt-relay-roster' ]; then
  roster='./.prompt-relay-roster'
elif [ -f "$HOME/.prompt-relay-roster" ]; then
  roster="$HOME/.prompt-relay-roster"
fi

if [ -n "$extra_log" ] && [ ! -f "$extra_log" ]; then
  printf 'Routing log not found: %s\n' "$extra_log" >&2
  exit 2
fi

now="$(date +%s)"
cutoff="$((now - since * 86400))"
if [ -n "$after_epoch" ] && [ "$after_epoch" -gt "$cutoff" ]; then
  cutoff="$after_epoch"
fi
find_days="$((since + 1))"

transcript_rows() {
  local root
  for root in "$codex_home/sessions" "$codex_home/archived_sessions"; do
    [ -d "$root" ] || continue
    find "$root" -type f -name 'rollout-*.jsonl' -mtime "-$find_days" -print0 2>/dev/null
  done | while IFS= read -r -d '' transcript; do
    # session_meta is the first JSONL row. Reject parent sessions before slurping
    # the full transcript; long interactive sessions can otherwise dominate a scan.
    IFS= read -r first_row < "$transcript" || continue
    if ! first_kind="$(printf '%s\n' "$first_row" | jq -r '
      if .type != "session_meta" then "other"
      elif .payload.source.subagent? != null then "subagent"
      else "parent" end
    ' 2>/dev/null)"; then
      printf 'Could not parse session metadata: %s\n' "$transcript" >&2
      continue
    fi
    [ "$first_kind" = 'subagent' ] || continue
    if ! row="$(jq -cs --arg transcript "$transcript" --argjson cutoff "$cutoff" '
      ([.[] | select(.type == "session_meta")][0] // null) as $meta
      | ([.[] | select(.type == "turn_context")][-1] // null) as $ctx
      | select($meta != null and ($meta.payload.source.subagent? != null))
      | select((try (($meta.payload.timestamp[0:19] + "Z") | fromdateiso8601) catch 0) >= $cutoff)
      | ([$meta.payload.source.subagent.thread_spawn.agent_role,
          $meta.payload.agent_path,
          $meta.payload.source.subagent.thread_spawn.agent_path]
         | map(select(type == "string" and length > 0))
         | .[0] // "?") as $raw_role
      | (($raw_role | split("/")[-1]) | split("__")[0]) as $role
      | {
          ts: $meta.payload.timestamp,
          harness: "codex-transcript",
          role: $role,
          model: ($ctx.payload.model // "unknown"),
          effort: ($ctx.payload.collaboration_mode.settings.reasoning_effort
                   // $ctx.payload.reasoning_effort
                   // $ctx.payload.effort
                   // ""),
          agent_id: ($meta.payload.id // "?"),
          parent_thread_id: ($meta.payload.parent_thread_id // ""),
          transcript_path: $transcript,
          evidence: $transcript,
          observation: "observed"
        }
    ' "$transcript" 2>/dev/null)"; then
      printf 'Could not parse subagent transcript: %s\n' "$transcript" >&2
      continue
    fi
    [ -n "$row" ] && printf '%s\n' "$row"
  done
}

legacy_rows() {
  [ -n "$extra_log" ] || return 0
  local parsed
  if ! parsed="$(jq -c --argjson cutoff "$cutoff" '
    select((.ts? // "") != "")
    | select((try (.ts | fromdateiso8601) catch 0) >= $cutoff)
    | {
        ts: .ts,
        harness: (.harness // "codex-log"),
        role: ((.role // "?") | tostring),
        model: ((.observed_model // .model // "unknown") | tostring),
        effort: ((.observed_effort // .effort // "") | tostring),
        requested_model: ((.requested_model // "") | tostring),
        requested_effort: ((.requested_effort // "") | tostring),
        agent_id: ((.agent_id // "?") | tostring),
        transcript_path: (.transcript_path // ""),
        evidence: ((.evidence // .transcript_path // "") | tostring),
        observation:
          (if ((.harness // "") == "forwarder") then
             if ((.observed_model? // "") | tostring) != ""
                and ((.observed_model? // "unknown") | tostring) != "unknown"
                and ((.evidence? // .transcript_path? // "") | tostring) != ""
                and ((.evidence? // .transcript_path? // "") | tostring) != "request-only"
             then "observed" else "requested-only" end
           elif (.observed_model? != null) then
             if ((.observed_model | tostring) == "" or (.observed_model | tostring) == "unknown")
             then "requested-only" else "observed" end
           elif (.model? != null) then "observed"
           else "requested-only" end)
      }
  ' "$extra_log" 2>/dev/null)"; then
    printf 'Could not parse routing log: %s\n' "$extra_log" >&2
    return 0
  fi
  [ -n "$parsed" ] && printf '%s\n' "$parsed"
}

raw_rows="$(transcript_rows; legacy_rows)"

if [ -z "$raw_rows" ]; then
  [ "$json_output" -eq 1 ] || printf '%s\n' 'No matching Codex delegations found.'
  exit 0
fi

roster_source='/dev/null'
[ -n "$roster" ] && roster_source="$roster"

rows="$(printf '%s\n' "$raw_rows" | jq -c --rawfile roster "$roster_source" '
  def roster_rules:
    [ $roster | split("\n")[]
      | gsub("^[[:space:]]+|[[:space:]]+$"; "")
      | select(length > 0 and (startswith("#") | not))
      | capture("^(?<agent>[^[:space:]]+)[[:space:]]+(?<model>[^[:space:]]+)(?:[[:space:]]+(?<effort>[^[:space:]]+))?$") ];
  . as $row
  | (roster_rules | map(select(.agent == $row.role)) | .[0] // null) as $rule
  | (if $rule == null then ""
     elif (($row.observation // "observed") != "observed")
          or (($row.model // "") == "")
          or (($row.model // "unknown") == "unknown")
          or ((($rule.effort? // "") != "") and (($row.effort // "") == ""))
     then "UNVERIFIED"
     elif (($row.model | ascii_downcase | contains(($rule.model // "") | ascii_downcase)) | not)
     then "MISMATCH"
     elif (($rule.effort? // "") != "") and (($row.effort // "") != $rule.effort)
     then "MISMATCH"
     else "" end) as $status
  | . + {
      date: (.ts[0:16] | gsub("T"; " ")),
      effort: (if (.effort // "") == "" then "not recorded" else .effort end),
      status: $status,
      expected_model: ($rule.model // ""),
      expected_effort: ($rule.effort // "")
    }
')"

issue_count="$(printf '%s\n' "$rows" | jq -s '[.[] | select(.status == "MISMATCH" or .status == "UNVERIFIED")] | length')"

if [ "$json_output" -eq 1 ]; then
  printf '%s\n' "$rows"
  [ "$issue_count" -eq 0 ]
  exit $?
fi

printf '%s\n' "$rows" | jq -r '[.date,.role,.model,.effort,.agent_id,.status] | @tsv' | awk -F '\t' '
  {
    date[NR]=$1; role[NR]=$2; model[NR]=$3; effort[NR]=$4; agent_id[NR]=$5; status[NR]=$6
    if (length(role[NR]) > role_width) role_width=length(role[NR])
    if (length(model[NR]) > model_width) model_width=length(model[NR])
    if (length(effort[NR]) > effort_width) effort_width=length(effort[NR])
    if (length(agent_id[NR]) > agent_id_width) agent_id_width=length(agent_id[NR])
    if (length(status[NR]) > status_width) status_width=length(status[NR])
  }
  END {
    if (role_width < 4) role_width=4
    if (model_width < 5) model_width=5
    if (effort_width < 6) effort_width=6
    if (agent_id_width < 8) agent_id_width=8
    if (status_width < 6) status_width=6
    printf "%-16s %-*s %-*s %-*s %-*s %-*s\n", "DATE", role_width, "ROLE", model_width, "MODEL", effort_width, "EFFORT", agent_id_width, "AGENT_ID", status_width, "STATUS"
    printf "%-16s %-*s %-*s %-*s %-*s %-*s\n", "----------------", role_width, "----", model_width, "-----", effort_width, "------", agent_id_width, "--------", status_width, "------"
    for (i=1; i<=NR; i++)
      printf "%-16s %-*s %-*s %-*s %-*s %-*s\n", date[i], role_width, role[i], model_width, model[i], effort_width, effort[i], agent_id_width, agent_id[i], status_width, status[i]
  }
'

printf '\nSummary (role / model / effort)\n'
printf '%s\n' "$rows" | jq -sr '
  group_by([.role, .model, .effort])
  | map({role:.[0].role, model:.[0].model, effort:.[0].effort, count:length})
  | sort_by(.count) | reverse
  | .[]
  | "  \(.role) / \(.model) / \(.effort): \(.count) delegation\(if .count == 1 then "" else "s" end)"
'

if [ "$issue_count" -gt 0 ]; then
  printf '\nRouting issues\n'
  printf '%s\n' "$rows" | jq -sr '
    .[] | select(.status == "MISMATCH" or .status == "UNVERIFIED")
    | if .status == "UNVERIFIED" then
        "  \(.role): requested route has no observed model/effort receipt"
      else
        "  \(.role): expected \(.expected_model)\(if .expected_effort == "" then "" else " / " + .expected_effort end); actual \(.model) / \(.effort)"
      end
  '
fi

[ "$issue_count" -eq 0 ]
