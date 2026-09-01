# Evals

Two suites, both cheap to run, both worth re-running after you edit your roster or the doctrine.

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

## Install eval
Tests the install path the way a stranger's agent will hit it — see
`evals/install-scenarios.md`. Four scenarios, checklist per scenario. These need a genuinely
fresh session; an agent that has already read this repo will pass them for the wrong reason.

## What these do not test
Neither suite measures cost. Whether delegation saves you money depends on your harness's
caching, your session lengths and your task mix — run `verify/` on your own logs for that, and
treat anyone's headline percentage, including ours, as their number rather than yours.
