#!/usr/bin/env bash
# check-routing.sh — verify Claude Code delegated to the expected models.
set -u

usage() {
  cat <<'EOF'
Usage: check-routing.sh [--since N] [--project SUBSTR] [--json] [--roster FILE]
EOF
}

read_row() {
  local transcript="$1"
  local roster_source="$2"
  local meta="${transcript%.jsonl}.meta.json"
  local meta_source='/dev/null'
  [ -f "$meta" ] && meta_source="$meta"

  jq -cs --rawfile roster "$roster_source" --slurpfile meta "$meta_source" '
    def roster_rules:
      [ $roster | split("\n")[]
        | gsub("^[[:space:]]+|[[:space:]]+$"; "")
        | select(length > 0 and startswith("#") | not)
        | capture("^(?<agent>[^[:space:]]+)[[:space:]]+(?<model>[^[:space:]]+)(?:[[:space:]]+(?<effort>[^[:space:]]+))?$") ];
    def text_or_question:
      if type == "string" and length > 0 then . else "?" end;
    reduce .[] as $line (
      {date:"?", models:[], efforts:[], assistant_turns:0,
       input_tokens:0, output_tokens:0};
      .date = if .date == "?" and (($line.timestamp? // "") | type) == "string"
               and (($line.timestamp? // "") | length) >= 16
               then (($line.timestamp[0:16] | gsub("T"; " "))) else .date end
      | if $line.type == "assistant" then
          .assistant_turns += 1
          | if (($line.message.model? // "") | type) == "string"
            and (($line.message.model? // "") | length) > 0
            then .models += [$line.message.model]
            else . end
          | if (($line.effort? // "") | type) == "string"
            and (($line.effort? // "") | length) > 0
            then .efforts += [$line.effort]
            else . end
          | .input_tokens += (if (($line.message.usage.input_tokens? // null) | type) == "number"
                              then $line.message.usage.input_tokens else 0 end)
          | .output_tokens += (if (($line.message.usage.output_tokens? // null) | type) == "number"
                               then $line.message.usage.output_tokens else 0 end)
        else . end
    )
    | ($meta[0] // {}) as $metadata
    | (($metadata.agentType? // "?") | text_or_question) as $agent_type
    | (($metadata.spawnDepth? // "?") | tostring) as $spawn_depth
    | (($metadata.description? // "?") | text_or_question
       | if length > 40 then .[0:37] + "..." else . end) as $description
    | (roster_rules | map(select(.agent == $agent_type)) | .[0] // null) as $rule
    | ((.models | unique | map(select(startswith("<") | not)) | if length == 0 then "?" else join(",") end)) as $model
    | ((.efforts | unique | if length == 0 then "?" else join(",") end)) as $effort
    | (try ($spawn_depth | tonumber) catch 0) as $depth_number
    | (if $rule == null then ""
       elif (($model | ascii_downcase | contains(($rule.model // "") | ascii_downcase)) | not)
         or (($rule.effort? // "") != "" and $effort != $rule.effort)
       then "MISMATCH" else "" end) as $status
    | {date:.date, agent_type:$agent_type, model:$model, effort:$effort,
       assistant_turns:.assistant_turns, output_tokens:.output_tokens,
       input_tokens:.input_tokens, spawn_depth:$spawn_depth,
       description:$description, marker:(if $depth_number > 1 then "!" else "" end),
       status:$status, expected_model:($rule.model // ""),
       expected_effort:($rule.effort // "")}
  ' "$transcript" 2>/dev/null
}

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' 'jq is required.' >&2
  exit 2
fi

if [ "${1:-}" = '--worker' ]; then
  read_row "$3" "$2"
  exit $?
fi

since=7
project_filter=''
json_output=0
roster=''

while [ "$#" -gt 0 ]; do
  case "$1" in
    --since)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      since="$2"
      shift 2
      ;;
    --project)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      project_filter="$2"
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

projects_dir="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"
if [ ! -d "$projects_dir" ]; then
  printf 'Claude projects directory not found: %s\n' "$projects_dir" >&2
  exit 2
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
roster_source='/dev/null'
[ -n "$roster" ] && roster_source="$roster"

now=$(date +%s)
cutoff=$((now - since * 86400))
rows=''
transcript_count=0
model_found=0
nested_count=0
mismatch_count=0
candidate_paths=()

while IFS= read -r -d '' transcript; do
  mtime=$(stat -f %m "$transcript" 2>/dev/null || stat -c %Y "$transcript" 2>/dev/null || printf '0')
  [ "$mtime" -ge "$cutoff" ] || continue

  session_dir="${transcript%/subagents/*}"
  project_slug="${session_dir##*/}"
  case "$project_slug" in
    *"$project_filter"*) ;;
    *) continue ;;
  esac

  transcript_count=$((transcript_count + 1))
  candidate_paths[${#candidate_paths[@]}]="$transcript"
done < <(find "$projects_dir" -type f -path '*/subagents/agent-*.jsonl' -print0)

if [ "$transcript_count" -eq 0 ]; then
  printf '%s\n' 'No matching Claude delegations found.'
  exit 0
fi

worker_rows=$(printf '%s\0' "${candidate_paths[@]}" \
  | xargs -0 -P 16 -n 1 bash "$0" --worker "$roster_source")
rows=''

while IFS= read -r row; do
  [ -n "$row" ] || continue
  rows="${rows}${row}"$'\n'
  case "$row" in
    *'"model":"?"'*) ;;
    *) model_found=1 ;;
  esac
  case "$row" in
    *'"marker":"!"'*) nested_count=$((nested_count + 1)) ;;
  esac
  case "$row" in
    *'"status":"MISMATCH"'*) mismatch_count=$((mismatch_count + 1)) ;;
  esac
done <<EOF
$worker_rows
EOF

if [ "$transcript_count" -gt 0 ] && [ "$model_found" -eq 0 ]; then
  printf '%s\n' 'The Claude on-disk format appears to have changed.' >&2
  printf '%s\n' 'Expected .message.model on "type":"assistant" lines and agentType in the .meta.json sibling.' >&2
  exit 2
fi

if [ "$transcript_count" -eq 0 ]; then
  printf '%s\n' 'No matching Claude delegations found.'
  exit 0
fi

if [ "$json_output" -eq 1 ]; then
  printf '%s' "$rows"
fi

if [ "$json_output" -eq 1 ]; then
  [ "$mismatch_count" -eq 0 ]
  exit $?
fi

printf '%s' "$rows" | jq -s -r 'sort_by(.date)[] | [.marker,.date,.agent_type,.model,.effort,(.assistant_turns|tostring),(.output_tokens|tostring),(.input_tokens|tostring),.spawn_depth,.description,.status] | @tsv' | awk -F '\t' '
  {
    marker[NR]=$1; date[NR]=$2; agent_type[NR]=$3; model[NR]=$4; effort[NR]=$5
    turns[NR]=$6; output_tokens[NR]=$7; input_tokens[NR]=$8; depth[NR]=$9
    description[NR]=$10; status[NR]=$11
    if (length(agent_type[NR]) > type_width) type_width=length(agent_type[NR])
    if (length(model[NR]) > model_width) model_width=length(model[NR])
    if (length(effort[NR]) > effort_width) effort_width=length(effort[NR])
    if (length(turns[NR]) > turns_width) turns_width=length(turns[NR])
    if (length(output_tokens[NR]) > output_width) output_width=length(output_tokens[NR])
    if (length(input_tokens[NR]) > input_width) input_width=length(input_tokens[NR])
    if (length(depth[NR]) > depth_width) depth_width=length(depth[NR])
    if (length(description[NR]) > description_width) description_width=length(description[NR])
    if (length(status[NR]) > status_width) status_width=length(status[NR])
  }
  END {
    if (type_width < 4) type_width=4
    if (model_width < 5) model_width=5
    if (effort_width < 6) effort_width=6
    if (turns_width < 5) turns_width=5
    if (output_width < 3) output_width=3
    if (input_width < 3) input_width=3
    if (depth_width < 5) depth_width=5
    if (description_width < 11) description_width=11
    if (status_width < 6) status_width=6
    printf "%1s %-16s %-*s %-*s %-*s %*s %*s %*s %*s %-*s %-*s\n", "", "DATE", type_width, "TYPE", model_width, "MODEL", effort_width, "EFFORT", turns_width, "TURNS", output_width, "OUT", input_width, "IN", depth_width, "DEPTH", description_width, "DESCRIPTION", status_width, "STATUS"
    printf "%1s %-16s %-*s %-*s %-*s %*s %*s %*s %*s %-*s %-*s\n", "", "----------------", type_width, "----", model_width, "-----", effort_width, "------", turns_width, "-----", output_width, "---", input_width, "---", depth_width, "-----", description_width, "-----------", status_width, "------"
    for (i=1; i<=NR; i++)
      printf "%1s %-16s %-*s %-*s %-*s %*s %*s %*s %*s %-*s %-*s\n", marker[i], date[i], type_width, agent_type[i], model_width, model[i], effort_width, effort[i], turns_width, turns[i], output_width, output_tokens[i], input_width, input_tokens[i], depth_width, depth[i], description_width, description[i], status_width, status[i]
  }
'

printf '\nSummary (agent type / model / effort)\n'
printf '%s' "$rows" | jq -sr '
  group_by([.agent_type, .model, .effort])
  | map({agent_type:.[0].agent_type, model:.[0].model, effort:.[0].effort,
         count:length, output:(map(.output_tokens) | add)})
  | sort_by(.output) | reverse
  | .[]
  | "  \(.agent_type) / \(.model) / \(.effort): \(.count) delegation\(if .count == 1 then "" else "s" end), \(.output) output tokens"
'

if [ "$nested_count" -gt 0 ]; then
  printf '\n! A delegate spawned its own delegate.\n'
fi

if [ "$mismatch_count" -gt 0 ]; then
  printf '\nRouting did not take\n'
  printf '%s' "$rows" | jq -sr '
    .[] | select(.status == "MISMATCH")
    | "  \(.agent_type): expected model \(.expected_model)\(if .expected_effort == "" then "" else " and effort " + .expected_effort end); actual model \(.model) and effort \(.effort)"
  '
fi

[ "$mismatch_count" -eq 0 ]
