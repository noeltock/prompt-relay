#!/usr/bin/env bash
# check-routing-codex.sh — verify Codex delegated to the expected models.
set -u

usage() {
  cat <<'EOF'
Usage: check-routing-codex.sh [--since N] [--json] [--roster FILE] [--log FILE]
EOF
}

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' 'jq is required.' >&2
  exit 2
fi

since=7
json_output=0
roster=''

while [ "$#" -gt 0 ]; do
  case "$1" in
    --since)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      since="$2"
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
    --log)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      ROUTING_LOG="$2"
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

log="${ROUTING_LOG:-$HOME/.codex/routing-log.jsonl}"
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
roster_source='/dev/null'
[ -n "$roster" ] && roster_source="$roster"

if [ ! -f "$log" ]; then
  printf 'Codex routing log not found: %s\n' "$log" >&2
  exit 2
fi

now=$(date +%s)
cutoff=$((now - since * 86400))
rows=$(jq -c --rawfile roster "$roster_source" --argjson cutoff "$cutoff" '
  def roster_rules:
    [ $roster | split("\n")[]
      | gsub("^[[:space:]]+|[[:space:]]+$"; "")
      | select(length > 0 and startswith("#") | not)
      | capture("^(?<agent>[^[:space:]]+)[[:space:]]+(?<model>[^[:space:]]+)(?:[[:space:]]+(?<effort>[^[:space:]]+))?$") ];
  select((.ts? // "") != "")
  | select((try (.ts | fromdateiso8601) catch 0) >= $cutoff)
  | ((.role? // "?") | tostring) as $agent_type
  | ((.model? // "?") | tostring) as $model
  | ((.effort? // "") | tostring) as $effort
  | (roster_rules | map(select(.agent == $agent_type)) | .[0] // null) as $rule
  | (if $rule == null then ""
     elif (($model | ascii_downcase | contains(($rule.model // "") | ascii_downcase)) | not)
     then "MISMATCH"
     elif (($rule.effort? // "") != "") and ($effort != "") and ($effort != $rule.effort)
     then "MISMATCH" else "" end) as $status
  | {date:(.ts[0:16] | gsub("T"; " ")), agent_type:$agent_type,
     model:$model, effort:(if $effort == "" then "not recorded" else $effort end),
     agent_id:(.agent_id? // "?"), status:$status,
     expected_model:($rule.model // ""), expected_effort:($rule.effort // "")}
' "$log" 2>/dev/null)

if [ -z "$rows" ]; then
  printf '%s\n' 'No matching Codex delegations found.'
  exit 0
fi

mismatch_count=$(printf '%s\n' "$rows" | jq -s '[.[] | select(.status == "MISMATCH")] | length')

if [ "$json_output" -eq 1 ]; then
  printf '%s\n' "$rows"
fi

if [ "$json_output" -eq 1 ]; then
  [ "$mismatch_count" -eq 0 ]
  exit $?
fi

printf '%s\n' "$rows" | jq -r '[.date,.agent_type,.model,.agent_id,.status] | @tsv' | awk -F '\t' '
  {
    date[NR]=$1; agent_type[NR]=$2; model[NR]=$3; agent_id[NR]=$4; status[NR]=$5
    if (length(agent_type[NR]) > type_width) type_width=length(agent_type[NR])
    if (length(model[NR]) > model_width) model_width=length(model[NR])
    if (length(agent_id[NR]) > agent_id_width) agent_id_width=length(agent_id[NR])
    if (length(status[NR]) > status_width) status_width=length(status[NR])
  }
  END {
    if (type_width < 4) type_width=4
    if (model_width < 5) model_width=5
    if (agent_id_width < 8) agent_id_width=8
    if (status_width < 6) status_width=6
    printf "%-16s %-*s %-*s %-*s %-*s\n", "DATE", type_width, "TYPE", model_width, "MODEL", agent_id_width, "AGENT_ID", status_width, "STATUS"
    printf "%-16s %-*s %-*s %-*s %-*s\n", "----------------", type_width, "----", model_width, "-----", agent_id_width, "--------", status_width, "------"
    for (i=1; i<=NR; i++)
      printf "%-16s %-*s %-*s %-*s %-*s\n", date[i], type_width, agent_type[i], model_width, model[i], agent_id_width, agent_id[i], status_width, status[i]
  }
'

printf '\nSummary (agent type / model)\n'
printf '%s\n' "$rows" | jq -sr '
  group_by([.agent_type, .model])
  | map({agent_type:.[0].agent_type, model:.[0].model, count:length})
  | sort_by(.count) | reverse
  | .[]
  | "  \(.agent_type) / \(.model): \(.count) delegation\(if .count == 1 then "" else "s" end)"
'
printf 'Token counts are not recorded in the Codex routing log.\n'
if grep -qE '^[^#[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+' "${roster:-/dev/null}" 2>/dev/null; then
  printf 'Rows showing effort "not recorded" came from Codex native fan-out, which does not report\nit; their effort was not checked, only the model. Rows written by a forwarder do carry effort.\n'
fi

if [ "$mismatch_count" -gt 0 ]; then
  printf '\nRouting did not take\n'
  printf '%s\n' "$rows" | jq -sr '
    .[] | select(.status == "MISMATCH")
    | "  \(.agent_type): expected model \(.expected_model)\(if .expected_effort == "" then "" else " effort " + .expected_effort end); actual model \(.model), effort \(.effort)"
  '
fi

[ "$mismatch_count" -eq 0 ]
