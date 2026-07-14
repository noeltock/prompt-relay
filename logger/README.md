# Routing log — starter

The one thing no public routing tool does yet: record which model handled which task, at what
effort, for what cost and outcome. Without it, your routing rules are inherited priors. With it,
they become measured fail-rate-per-dollar you can tune to *your* stack.

This is a starter, not a product: one append-only JSONL file, one hook, zero dependencies beyond
`jq`.

## Schema
One JSON object per line (`~/.claude/routing-log.jsonl` by default, override with `$ROUTING_LOG`):
```json
{ "ts": "2026-07-14T09:00:00Z", "task_class": "mechanical-edit", "role": "coder-low",
  "model": "luna", "effort": "high", "tokens": 12000, "duration_s": 40, "outcome": "pass" }
```
`outcome` ∈ `pass | fail | reroute | blocker`.

## Wire it up (Claude Code)
Add a `SubagentStop` hook to `~/.claude/settings.json` (merge, don't clobber):
```json
{
  "hooks": {
    "SubagentStop": [
      { "hooks": [ { "type": "command",
        "command": "/ABSOLUTE/PATH/prompt-relay/logger/log-delegation.sh" } ] }
    ]
  }
}
```
`log-delegation.sh` reads the stop event on stdin and appends a row. The event carries `tokens` and
`duration`; `task_class` / `model` / `effort` usually don't — pass them from the spawn site via env
(`ROUTING_TASK_CLASS`, `ROUTING_MODEL`, `ROUTING_EFFORT`, `ROUTING_OUTCOME`) or enrich the JSONL in a
later pass. Adjust the `jq` field paths in the script to match your harness's actual payload.

## Read it
Fail-rate and cost per (class, model, effort) — the numbers that tune your routing table:
```bash
jq -s '
  group_by([.task_class, .model, .effort])
  | map({ key: (.[0].task_class+" / "+.[0].model+" / "+.[0].effort),
          n: length,
          fail_rate: ((map(select(.outcome=="fail"))|length) / length),
          avg_tokens: ((map(.tokens)|add) / length) })
  | sort_by(.fail_rate)
' ~/.claude/routing-log.jsonl
```
Low fail-rate for a cheap tier on a class → push more of that class down. A spike → that's your
escalate signal, now backed by your own data. Prefer SQL? `jq -c . routing-log.jsonl` imports
cleanly into SQLite / DuckDB.

## Note
This starter logs the *decision and its outcome*, not code quality — `pass/fail` is easy to capture,
"was it good" is not. Even token-and-fail-rate-per-class is more than anyone else is measuring.
