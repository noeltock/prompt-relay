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
