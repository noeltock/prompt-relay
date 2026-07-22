# Routing log — starter

The one thing no public routing tool does yet: record which model handled which task, at what
effort, for what cost and outcome. Without it, your routing rules are inherited priors. With it,
they become measured fail-rate-per-dollar you can tune to *your* stack.

This is a starter, not a product: one append-only JSONL file, one hook, zero dependencies beyond
`jq`.

## Schema
One JSON object per line (`~/.claude/routing-log.jsonl` by default, override with `$ROUTING_LOG`):
```json
{ "ts": "2026-07-14T09:00:00Z", "task_id": "a1b2c3", "task_class": "mechanical-edit",
  "role": "coder-low", "model": "luna", "effort": "high", "outcome": "pass" }
```
`outcome` ∈ `pass | fail | reroute | blocker-environment | blocker-decision` — split so an
environment blocker (no DNS, missing CLI, denied permission) doesn't get lumped in with a genuine
decision blocker; only the latter should ever trigger "answer it and re-spawn the same role."

**No tokens / duration_s field.** A real Claude Code `SubagentStop` payload does not carry usage
or timing data (it carries `session_id` / `transcript_path` / `cwd` / `agent_type`, not
`subagent_type` / `usage` / `duration_ms`) — an earlier version of this script read fields that
don't exist and every row silently came out `role:"unknown", tokens:0`. `role` now reads
`agent_type`, which does exist; `tokens`/`duration_s` are dropped rather than fabricated.

**`task_id` / `task_class` / `model` / `effort` / `outcome` capture is manual, not automatic.**
There is no Claude Code spawn point that exports `ROUTING_*` env vars into the subagent's process
before it starts, so these fields only populate when a harness wrapper sets them explicitly (e.g. a
shell wrapper around `claude` that exports them per task). As shipped, treat this JSONL as a
skeleton you enrich by hand (or via a small script matching `transcript_path` back to the lead
session) after the fact — not a fully automatic capture. `task_id` is a session-scoped id shared by
every delegate spawned for one lead-level task; without it, rows are per-call, and you can't compute
a fail rate for the *task* as a whole, only for individual delegations, which understates repeated
escalations.

## Wire it up (Claude Code)
Add a `SubagentStop` hook to `~/.claude/settings.json` (merge, don't clobber — see
`settings.example.json` at the repo root for the combined fragment covering both this hook AND
`hooks/pre-commit-checklist.sh`; pasting the two READMEs' `"hooks"` blocks separately would clobber
one with the other):
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
`log-delegation.sh` reads the stop event on stdin and appends a row. The event carries `agent_type`
(mapped to `role`); it does NOT carry `task_id` / `task_class` / `model` / `effort` / tokens /
duration — those fields only populate if a harness wrapper exports `ROUTING_TASK_ID`,
`ROUTING_TASK_CLASS`, `ROUTING_MODEL`, `ROUTING_EFFORT`, `ROUTING_OUTCOME` into the environment
before the spawn (no Claude Code Task-spawn point does this natively), or you enrich the JSONL by
hand in a later pass.

**Blind spot: `SubagentStop` fires on completion, not on a crash or a killed delegate.** A hung or
force-killed sub-agent writes no row at all, so a fail-rate computed from this log silently omits
its worst outcomes — the delegations that never finished cleanly. If you kill a wedged delegate
(see the cross-vendor guardrails in `references/routing.md`), append a row by hand with
`outcome: fail` so the count isn't skewed rosy.

## Read it
Fail-rate and cost per (class, model, effort) — the numbers that tune your routing table:
```bash
jq -s '
  group_by([.task_class, .model, .effort])
  | map({ key: (.[0].task_class+" / "+.[0].model+" / "+.[0].effort),
          n: length,
          fail_rate: ((map(select(.outcome=="fail"))|length) / length) })
  | sort_by(.fail_rate)
' ~/.claude/routing-log.jsonl
```
Or per-task, once you have `task_id` — did the *task* need an escalation anywhere along the way,
not just any single call:
```bash
jq -s '
  group_by(.task_id)
  | map({ task_id: .[0].task_id, calls: length,
          escalated: (map(select(.outcome=="reroute" or .outcome=="blocker-environment" or .outcome=="blocker-decision"))|length > 0) })
' ~/.claude/routing-log.jsonl
```
Low fail-rate for a cheap tier on a class → push more of that class down. A spike → that's your
escalate signal, now backed by your own data. Prefer SQL? `jq -c . routing-log.jsonl` imports
cleanly into SQLite / DuckDB.

## Promoting a repeat fail to a guaranteed check
The log tells you *that* a `task_class` keeps failing; it doesn't fix it. When the same class shows
`outcome: fail` twice, don't just note it — add a line to `learned/known-failures.md`. That file
gets printed before every commit by `hooks/pre-commit-checklist.sh`, so the second occurrence
becomes the last one: see `hooks/README.md`.

## Note
This starter logs the *decision and its outcome*, not code quality — `pass/fail` is easy to capture,
"was it good" is not. Even token-and-fail-rate-per-class is more than anyone else is measuring.
