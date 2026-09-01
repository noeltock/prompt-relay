# Routing verification

These scripts answer one question: did the delegate that actually ran match the model and effort
you intended to route to?

## Run it

Claude Code reads its transcripts directly:

```bash
bash verify/check-routing.sh --since 7
```

Codex reads the JSONL written by `verify/log-delegation-codex.sh`:

```bash
bash verify/check-routing-codex.sh --since 7
```

Use `--json` for one JSON object per delegation. Claude also supports `--project SUBSTR`. Both
commands accept `--roster FILE`; without it they check `./.prompt-relay-roster`, then
`$HOME/.prompt-relay-roster`.

Example:

```text
DATE             TYPE       MODEL             EFFORT TURNS OUT   IN DEPTH DESCRIPTION              STATUS
2026-09-01 10:14 qa-runner claude-haiku-5     low        4  1,204  8,110     1 Verify routing demo

Summary (agent type / model / effort)
  qa-runner / claude-haiku-5 / low: 1 delegations, 1,204 output tokens
```

## Roster

Write one rule per line: `agentType expected-model-substring [expected-effort]`.

```text
# role             model substring       effort
qa-runner          haiku                  low
researcher         sonnet                 high
coder              opus
reviewer           fable                  xhigh
```

`MISMATCH` means the observed model or effort did not satisfy its rule; the command exits 1.
The usual causes are an unpinned delegate inheriting the lead model, or a model name that no
longer exists so the harness fell back to another model.

## Limits

The Claude script reads an undocumented on-disk layout that can change on any upgrade. It counts
only delegations whose transcripts are still on disk, and a delegate killed mid-run may leave a
partial transcript. Codex's hook log records neither effort nor token counts, so those columns are
not shown there.

## Wiring the Codex hook
Claude Code needs no hook — `check-routing.sh` reads transcripts the harness already writes.
Codex does: add `verify/log-delegation-codex.sh` as a `SubagentStop` hook so there is a log for
`check-routing-codex.sh` to read.

```json
{ "SubagentStop": [ { "command": "/ABSOLUTE/PATH/prompt-relay/verify/log-delegation-codex.sh" } ] }
```

Its field paths were taken from the Codex 0.145.0 payload schema. One of them — `model`, the field
that makes the whole check possible — could not be re-confirmed against 0.152.0 by inspecting the
binary. Run one spawn, look at your own log row, and confirm the model came through before relying
on it. If that column is empty, the script says so rather than guessing.

## Three cases, and which script covers each
| What you run | Covered by | How |
|---|---|---|
| Claude Code sub-agents | `check-routing.sh` | reads the transcripts Claude Code already writes |
| Codex native fan-out | `check-routing-codex.sh` | reads the log its `SubagentStop` hook writes |
| A Claude agent shelling out to another vendor's CLI | `check-routing-codex.sh` | reads rows the forwarder writes itself |

That third case is the one to watch. The Claude-side check sees only the wrapper's own cheap model
and has no idea which model the external CLI ran, so a forwarder that doesn't log its own row
leaves your cross-vendor routing completely unverified — which, for a cross-vendor setup, is most
of your spend. `agents/coder-forwarder.example.md` ships with that logging step; keep it.

## Pointing it somewhere else
`check-routing.sh` reads `$HOME/.claude/projects` unless you set `CLAUDE_PROJECTS_DIR`. If you
installed into a project directory rather than your home config, set it — otherwise you'll get a
clean report about the wrong sessions. `check-routing-codex.sh` takes `ROUTING_LOG` the same way.

## What the Codex check cannot see
Codex reports a spawned agent as one of its three built-in roles — `explorer`, `worker`,
`default` — so `coder-low`, `coder-high` and `qa` all arrive as `worker` and are told apart only
by effort, which the payload does not record. Two consequences worth being clear about:

- Roster lines for Codex are **role and model**. If you add an effort column the script says so
  and checks the model only, rather than failing you for data that was never captured.
- It catches the expensive failure — a subagent inheriting or falling back to your lead model —
  and cannot catch a cheap role running at the wrong effort. The Claude side records effort and
  checks both.

The example rosters above use Claude-side agent names, which come from the sidecar file Claude
Code writes. On Codex, use the built-in role names instead.
