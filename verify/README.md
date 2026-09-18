# Routing verification

These scripts answer one question: did the delegate that actually ran match the model and effort
you intended to route to?

## Run it

Claude Code reads its transcripts directly:

```bash
bash verify/check-routing.sh --since 7
```

Codex now reads its session transcripts directly too:

```bash
bash verify/check-routing-codex.sh --since 7
```

Use `--json` for one JSON object per delegation. Both commands accept `--roster FILE`; without it
they check `./.prompt-relay-roster`, then `$HOME/.prompt-relay-roster`.

`--since N` is whole days, so it cannot exclude yesterday evening's runs from a run this morning.
`--after TIMESTAMP` sets an absolute floor (epoch seconds, `YYYY-MM-DD`, or `YYYY-MM-DDTHH:MM:SS`)
and takes whichever of the two is later. Pass your install time on the first run: a roster written
today is otherwise applied to delegations that predate it, which fails for work that was never
misrouted.

The `DATE` column shows the transcript's own UTC timestamp, while the filters compare file mtime.
The instant is the same either way, but read a `--after` value off your clock, not off the column.

## Waiting on a job

```bash
bash verify/wait-on-liveness.sh --latest
bash verify/wait-on-liveness.sh --id <job-id> --budget 480 --stall 300
```

Polls the companion's per-job `updatedAt`, which advances on each turn, instead of imposing a
deadline. Exits **0** finished, **2** still working so call again, **3** wedged (`updatedAt` frozen
past `--stall`), **4** no such job.

Three ambiguities it resolves rather than guesses at.

A status call that fails or returns junk is reported as *unavailable*, which is distinct from a
valid reply that does not list the job. Absent status is absent information, so it can never produce
**any** verdict about the job: not "finished", not "stalled", not "no such job". Only a valid reply
showing the job absent counts toward completion, and it takes `--misses` of them (default 2).
Status that stays unavailable for a whole `--stall` window exits **1**, an environment error.

`--latest` latches onto the newest running job at first sighting and then follows that id, so a
second job starting cannot quietly become the thing being waited on.

The last observed turn is **persisted per job id** across calls (`--state-dir`, default under
`$TMPDIR`). `--budget` sits below `--stall` by design so a call always returns inside a harness
ceiling, which means a stall is only ever reachable across several calls; without persistence each
retry reset the clock and a wedged job reported "running" forever. A state directory that cannot be
written is therefore an error (exit 1), not a silent skip: continuing with "call again" would
reinstate exactly that bug.

Set `--stall` above the longest single turn you expect. The signal is per-turn, so a job in the
middle of a long turn is legitimately quiet; too tight a stall window reads that as a hang.

The **2** is the useful one. `--budget` defaults to 480 seconds so a call always returns inside a
600-second harness ceiling; a job that outlives it is polled again rather than killed and restarted.
A slow job and a hung job therefore stop sharing a symptom, which a wall-clock timeout cannot
achieve.

## Roster

Write one rule per line: `[harness:]agent-role expected-model-substring [expected-effort]`.

The `harness:` scope is optional. A bare name applies to both verifiers, which is what every
roster written before this existed contains, so old files keep parsing unchanged.

**But parsing unchanged is not the same as correct.** If your existing roster has an `advisor` row,
it is bare, so it still reaches both verifiers and the Claude one still fails on every advisor run.
Merging the scope support does not fix that; editing the roster does. Migrate in one pass: prefix
every existing row with the harness it was written for, then add the Claude rows below.

```text
# Codex custom role   model             effort
codex:coder_small     gpt-5.6-luna      high
codex:coder_low       gpt-5.6-luna      high
codex:coder_high      gpt-5.6-sol       medium
codex:runner          gpt-5.6-luna      medium
codex:qa              gpt-5.6-luna      medium
codex:advisor         gpt-6-astra       medium
codex:council         gpt-6-astra       high

# Claude agent type    model             effort
claude:advisor         claude-fable      medium
claude:Explore         claude-haiku
claude:general-purpose claude-sonnet
claude:coder_low       claude-sonnet     medium
claude:coder_high      claude-sonnet
claude:qa              claude-sonnet     medium
claude:runner          claude-haiku
```

**Scope the rows for any role that exists on both sides.** `advisor` is the one that bites: it is a
two-stage panel, the Codex stage runs `gpt-6-astra` and the Claude stage runs Fable. A single
unscoped `advisor gpt-6-astra medium` row therefore makes the Claude verifier report `MISMATCH` on
every advisor run it ever sees, and exit 1 with it. Scoping the row is the fix; there is nothing
wrong with the routing it was flagging.

**The Claude column is the agent type, verbatim.** It is what appears in the `AGENT` column of a
run: the `name:` from `~/.claude/agents/<name>.md` for a custom agent, or the built-in type
(`Explore`, `general-purpose`) for a scout. Your own agent names go here, so this column will not
match the Codex one unless you happen to have named them the same. It is case-sensitive:
`Explore`, not `explore`.

**Check the `Coverage` line before you trust a clean run.** A satisfied rule, a rule scoped to the
other harness and no rule at all all print an empty status, so a roster that matches nothing looks
identical to a roster where everything passed. The verifier now says how many delegations were
actually judged and names the agent types it skipped. A roster carrying only Codex role names will read
`0 of N delegations were checked` on the Claude side, which is the failure mode this line exists to
make visible: a clean run over a roster that checks nothing.

**Only set an expected effort where effort is observable.** Agents whose transcripts show `?` in the
`EFFORT` column (Haiku runners, for instance) will never satisfy an effort rule. Leave the third
column off for those and the model alone is checked.

`MISMATCH` means observed model/effort did not satisfy the rule. `UNVERIFIED` means the row records
only a request or lacks an observed field required by the roster. Either status exits 1. A row
without a roster rule is shown but does not fail. Common failures are an untyped spawn inheriting
the parent, a skill- or slash-command-launched agent inheriting the lead because no `Task` tool call
fired for a hook to catch, an unavailable pin falling back, or a forwarder logging intent instead of
evidence.

## How the Codex check works

`check-routing-codex.sh` scans `sessions/` and `archived_sessions/` under `$CODEX_HOME` (default
`~/.codex`). It selects real subagent sessions from `session_meta`, then reads the actual model and
effort from the final `turn_context` in the same transcript.

Codex records the custom role in `agent_role` on surfaces that expose it. When that field is empty,
the verifier falls back to the last component of `agent_path`. Name those tasks with the role first,
using two underscores as the separator—for example `runner__docs_sweep`. The verifier normalizes
that to `runner`, keeping the row comparable to the roster.

Use `--codex-home DIR` for a different Codex home. Use `--log FILE` to add legacy SubagentStop-hook
rows or rows written by the cross-vendor forwarder:

```bash
bash verify/check-routing-codex.sh --since 7 --log ~/.codex/routing-log.jsonl
```

The hook logger remains in this directory for older installs and forwarders, but native Codex
verification no longer depends on a hook payload carrying `model` or `effort`.

## Canary rule

Run one harmless canary for each model/effort pair after install and every Codex/model update. A
model catalogue flag is inventory, not proof of the spawn path. On Codex CLI 0.153.4, a Luna row
still advertised multi-agent `v1`, while a live v2 parent successfully spawned a Luna-medium leaf;
the transcript recorded `gpt-5.6-luna / medium`.

## Limits

- The on-disk transcript is an internal format and may change. A missing role/model/effort must be
  reported as unavailable, never inferred.
- A deleted transcript cannot be audited.
- Model/effort receipts prove routing, not output quality or allowance savings. Join these rows to
  accepted outcomes if you want to evaluate the roster.
- A bounded canary proves that pair on that build/account/surface. Re-check after upgrades.

## Cross-vendor forwarders

A Claude agent that shells out to Codex must still write its own JSONL row. Claude's transcript
sees only the wrapper, while Codex's spawned session may live under another home or be archived.
`agents/coder-forwarder.example.md` records requested and observed routing separately. A
request-only row is deliberately `UNVERIFIED`. For Codex, capture the documented
`thread.started.thread_id` from `codex exec --json`, retain the matching transcript as evidence,
and archive only that exact ID. Pass the forwarder log with `--log FILE`.
