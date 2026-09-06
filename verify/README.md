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

## Roster

Write one rule per line: `agent-role expected-model-substring [expected-effort]`.

```text
# Codex custom role  model             effort
coder_low            gpt-5.6-terra     medium
coder_high           gpt-5.6-terra     high
advisor              gpt-6-astra       medium
qa                   gpt-5.6-luna      medium
runner               gpt-5.6-luna      medium
```

`MISMATCH` means observed model/effort did not satisfy the rule. `UNVERIFIED` means the row records
only a request or lacks an observed field required by the roster. Either status exits 1. A row
without a roster rule is shown but does not fail. Common failures are an untyped spawn inheriting
the parent, an unavailable pin falling back, or a forwarder logging intent instead of evidence.

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
