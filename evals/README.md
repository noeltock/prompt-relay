# Evals

Four evaluation surfaces, all cheap to run and worth revisiting after you edit the roster,
installer, verifier, or routing doctrine.

## Routing eval
Tests whether the route table actually decides. Paste this to a fresh agent session:

> Read `profiles/claude-CLAUDE.md` (or `profiles/codex-AGENTS.md`). Then, for each of the 20
> tasks in `evals/routing-cases.md`, name the role you would route it to and one line of
> reasoning. Do not read the "Expected" column — answer cold, then compare.

Grade only the role column. Score out of 20.

- **18+** — the doctrine is doing its job.
- **14–17** — look at *which* ones missed. Clustered misses mean an ambiguous rule; scattered
  misses usually mean the model isn't reading the route table at all, which is a placement
  problem (is the core actually loading every turn?).
- **<14** — the core is too long, buried, or not loaded. Check it's in the file your harness
  reads, not one it ignores.

## Codex policy cases

In a fresh session, supply only **Model routing & delegation** from the Codex profile and the
Scenario column below. Ask for the next action and route, without executing anything; compare
against the acceptance column afterwards. These check decisions, not actual context size or routing.

| Scenario | Acceptance |
|---|---|
| The label edit is obvious in the open file; local proof mode permits only useful independent delegation. | Edit inline; no mandatory worker. |
| A compatible idle `coder_low` just finished the first part of the same issue. | Reuse after checking host, checkout and ownership; supply changed scope. |
| That worker's last receipt says Terra/medium; its TOML now says Luna/high. | Do not call it verified Luna; inspect the next turn or create and verify a fresh worker. |
| A QA brief names three CLI checks and requires no visual evidence. | Execute those checks; do not add browser/UI auditing. |
| A runner uses `fork_turns="none"`; a standalone CLI task had a smaller prompt. | No empty-context or savings claim; no global memory/settings change without relevant measurement. |
| Rename the exported `buildInvoice` helper to `createInvoice` in seven named source files; references and checks are listed. | `coder_low`: bounded code edits, even when mechanical. |
| Rename a column in six supplied CSV exports and write the results to named output files. | `runner`: bounded non-code transformation. |
| Apply the diagnosed null-handling fix across three named modules, following the supplied patch and regression checks. | `coder_low`: the fix is settled, despite involving a bug. |
| Repair the failing `payment.test.ts` case; its stack trace identifies the module, but the cause is unknown. | `coder_high`: bounded diagnosis, not a settled fix. |
| Implement the approved request-throttling design: limits, identity key, storage, failure behaviour, files and checks are specified. | `coder_low`: implement settled security decisions. |
| Stop automated sign-ups from overwhelming the service; no traffic policy or approach has been chosen. | Lead scopes and decides before delegating implementation. |

## Install eval
Tests the install path the way a stranger's agent will hit it — see
`evals/install-scenarios.md`. Five scenarios, checklist per scenario. These need a genuinely
fresh session; an agent that has already read this repo will pass them for the wrong reason.
Successful install scenarios must also produce the canonical activation receipt: one compact
roster table, honest verification states, and an explicit fresh-session instruction.

## Codex verifier eval

Tests transcript parsing, role normalization, model/effort comparison, mismatch exit status, and
legacy-log combination. It also covers empty custom roles, request-only forwarders, JSON empty
results, independently evidenced forwarder observations, and malformed transcript/log reporting.
Reused-worker cases cover turn-time cutoffs, earlier mismatches surviving later matches, missing
fields, archived sessions and absent contexts:

```bash
bash evals/run-codex-verifier-evals.sh
```

It uses synthetic session JSONL in a temporary Codex home and never calls a model.

## Claude verifier eval

Tests roster rule matching for `verify/check-routing.sh`: harness scoping, backwards compatibility
with unscoped rows, effort comparison, and case-insensitive scopes.

```bash
bash evals/run-claude-verifier-evals.sh
```

It builds synthetic subagent transcripts and `.meta.json` sidecars in a temp dir and never calls a
model. The load-bearing case is the first one: a roster holding both `codex:advisor` and
`claude:advisor` must not fail the Claude stage. Before harness scoping there was no Claude-side
harness at all, and that false positive ran unnoticed against live transcripts.

## Liveness eval

Tests `verify/wait-on-liveness.sh`: the four exit codes, and that a slow job and a wedged job are
distinguishable.

```bash
bash evals/run-liveness-evals.sh
```

It drives a stub companion reading a scripted sequence of status payloads, so no model runs and the
suite finishes in seconds. The load-bearing cases are that a job past its budget whose `updatedAt`
is still advancing exits 2 while a frozen one exits 3, and that a single malformed status reply is
read as neither finished nor stalled.

## Hook eval
Tests whether the enforcement layer (`hooks/claude/`) actually decides, deterministically — no
model or judgment call involved. Run it directly:

```bash
bash evals/run-hook-evals.sh
```

It builds fixtures in a temp dir, feeds each hook synthetic `PreToolUse` JSON, and checks the
decision against the 17 cases in `evals/hook-cases.md` — deny/allow for the two read guards,
`updatedInput.model` for the scout pin. PASS/FAIL per case, exit 1 on any failure. Re-run after
editing a hook or changing `RELAY_MIN_LINES`/`RELAY_SCOUT_MODEL` defaults.

## What these do not test
None of these suites measures cost. Whether delegation improves the workflow depends on your harness's
caching, your session lengths and your task mix — run `verify/` on your own logs for that, and
treat anyone's headline percentage, including ours, as their number rather than yours.
