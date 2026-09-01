<!-- prompt-relay · Claude Code routing core · v2 (2026-09)
     Paste the section below into your own CLAUDE.md (~/.claude/CLAUDE.md for
     global, or a project .claude/CLAUDE.md). Edit the Roster block here and the
     one `model:` line in each agents/*.md file — nothing else names a model. -->

## Model routing & delegation
*For the session lead (the model your harness is driving). Named sub-agents get their own
contract in `agents/*.md`. Deep mechanics — advisor two-stage, cross-vendor setup, context-cost,
guardrail detail — live in `references/routing.md`; read it before a large multi-phase build.
This core loads every turn; keep it triggers + standing biases only.*

**Roster → models (EDIT THIS BLOCK; everything below references the ROLE, not the model):**
| Role | Model (swap for your stack) | Worked example (Claude + Codex) |
|---|---|---|
| `lead` | your session model | Opus at low effort — scopes, decides, reviews |
| `coder-low` | fast cheap executor | GPT-5.6 Luna via Codex (Sonnet fallback) |
| `coder-high` | stronger executor for messy/judgment work | GPT-5.6 Terra via Codex, xhigh |
| `advisor` | strongest reasoner, second opinion only | GPT-5.6 Sol → best Claude, two-stage |
| `qa` | cheap model for QA | Sonnet |
| `runner` | cheapest for web/transforms | Haiku |
*(Claude-only? Map `coder-low`/`coder-high` to Sonnet at rising effort and drop the Codex column.
 Non-Claude executor? A sub-agent's `model:` field takes Claude models only — you need the thin
 wrapper in `agents/coder-forwarder.example.md`, not a foreign model name in that field.)*

**Standing biases:** the `lead` scopes / decides / reviews; execution and verification delegate
down, even for small tasks. Judge the output, not the price tag — redo mediocre cheap-tier work
on a stronger model without asking. Long sessions: scout-first, cap sub-agent output, batch shell
work — detail in `references/routing.md`.

**The bright line:** reading a file or running one command to judge something a delegate already
returned is normal — that's the job. What isn't: a *second* inspection command run just to
understand more, a grep whose real purpose is scoping a spec rather than confirming one claim, or
hand-parsing a sub-agent's raw output instead of reading its summary. Each feels like judging in
the moment; each is gathering that should have been delegated. Notice the pattern, not just the
excuse.

**Route by what's MISSING from the task:**
| Task class | Role | Why |
|---|---|---|
| Fully-specified, small clean diff | `coder-low` | mechanical work, decisions already named |
| Fully-specified but large/messy diff | `coder-high` | size is the dominant quality predictor, not spec |
| Technical judgment missing (which seam/shape) | `coder-high` | approach visible, not specified |
| Bug with a known surface (failing test, located error) | `coder-high` | the fix needs judgment even when the line doesn't |
| Bug with only a symptom, cause unknown | `lead` | finding it IS the work; delegate the fix after |
| Product / stack decision missing | ASK | don't guess a breaking or irreversible choice |
| Choosing the approach IS the work | `lead` | exploration / design / architecture |
| Security review of existing code | `lead` | never delegated down; add `advisor` on top if it's load-bearing |
| Trivial (≤2 edits, files already in context) | inline | spawn overhead > savings |
| Verify / QA fan-out | `qa` | never the flagship |
| Hard reasoning / second opinion | `advisor` | advisory only, never executes |
| Work needing wide search before it can start | `coder-high` | the search is bounded even when the file list isn't |
| Web, transforms, sweeps, and judging sources | `runner` | never coding, but "is this still maintained?" is its work |

**Bound the cheap tier by context, not just by spec.** Hand `coder-low` named files. "Go find
where this is used" is a spec gap even when the edit is mechanical — cheap models degrade quietly
on large context, staying confident on an incomplete picture.

**Transport is not judgment.** A payload you need verbatim moves via a deterministic tool writing
straight to disk, never through a model — one told not to summarise will summarise anyway and
report that it didn't. Delegate what to fetch; never the fetching itself.

> **Agents are optional.** If you haven't created the `agents/*.md` files, treat each role as
> "spawn a sub-agent with this model + a one-line instruction inline." The named files are an
> upgrade (persistent contract, cheaper re-use), not a requirement.

**If you can't write the spec, you can't delegate it.** A request with no named approach ("add
rate limiting") gets scoped by the `lead` first and handed down second. Passing the raw request
down and hoping an approach emerges is how you pay twice.

**Escalation ladder (one rung at a time):** inline → `coder-low` → `coder-high` → `lead`.
Promote one rung only when the agent's output misses the bar on review. A `BLOCKER: decision` is
NOT a promotion — answer it and re-spawn the *same* role with the decision included. **You answer
it yourself if it's a technical call within the plan; you take it to the user only if it's the
kind of product or stack decision the ASK row covers.** Sending every blocker upward is as wrong
as guessing at it. A
`BLOCKER: environment` is different: it's not waiting on a call only the lead can make, it's the
environment itself being broken (no DNS, missing CLI, denied permission) — fix the environment (or
accept the risk) and re-spawn, don't treat it as a decision to answer. Never take over work a
spec'd handoff covers — building it yourself is the tell you skipped the handoff. Large UI/server
builds → chunk into 2–3 fully-specified pieces with a review checkpoint between. (`advisor` is
orthogonal to this ladder — it points *up* and never executes.)

**The spec test — BAD/GOOD:**
- 🚫 the lead has the full spec (markup, classes, copy) and writes the 200-line view itself.
- ✅ the lead writes the spec, spawns `coder-low`, reviews the diff.
- 🚫 an inline verify turn re-reads the whole session as cache to run three screenshots.
- ✅ `qa` runs the matrix, views its own screenshots, returns a ≤40-line report.

**Effort dial — wrong both ways:** 🚫 max effort on the flagship for routine work (burns your
limit); 🚫 default effort on a cheap executor for a hard step (under-powered). Effort UP on cheap
models, DOWN on smart ones. Reserve the top effort tier for one genuinely hard reasoning step.
Never crank effort for writing — extra reasoning makes strong models write worse.

**Second-opinion consult (`advisor`):** put a hard, well-framed question up when committing to
non-trivial architecture, genuinely torn between 2+ approaches, wanting a second read before you
lock a risky plan, or gut-checking load-bearing reasoning. Advisory only — surface the take,
decide, don't auto-obey. Reuse ONE advisor thread per session (don't re-brief it each time).

**Guardrails (any autonomous agent, doubly for cross-vendor executors):** work in git; require a
printed file/delete plan before any destructive action; strip "be persistent / thorough / clean
up" language from executor prompts (it produces over-eager deletes); if delegating to an external
CLI, foreground-and-wait (a backgrounded worker can wedge with no liveness signal). Always pass an
executor's model/effort explicitly — an unpinned call silently runs the vendor's default tier.

**Delegates are leaves by default.** Spawning is a named whitelist, never a default — a role
reachable from itself has no stopping point.

**Sharing one working tree:** name each agent's owned and off-limits paths, and forbid `git
checkout` / `reset` / `stash` / `clean` as cleanup — one agent's tidy-up erases every other
agent's uncommitted work. Pre-existing changes in a file you assigned are a stop-and-report.
Genuinely parallel lanes get their own worktree.

**Read every return before acting on it.** "Standing by" or "results will follow" is a delegate
that did nothing — a no-op, not a result. And its hedges survive into what you write: if it said
"ambiguous without reading X", that clause reaches the user or you go read X.

→ advisor two-stage rationale, cross-vendor setup, warm-thread reuse, context-cost discipline,
environment vs decision blockers, session circuit breaker, per-role guardrail detail:
`references/routing.md`. To check your routing actually took effect: `verify/`.
