# Model routing — deep mechanics

On-demand reference for the routing core in `CLAUDE.md`. Read before a large multi-phase build.
Holds the rationale, operational detail, and hard-won rules that don't fit in the always-loaded
core — the *why*, and the intricacies that only show up once you're running this at scale.

## The one idea
An expensive, smart model is worth its price for **deciding** (scope, architecture, review) and
wasteful for **typing** (mechanical execution). So the lead decides and delegates; cheap models
execute; a strong model advises on the few hard calls. Everything else is detail.

## The roles in full
- **`lead`** — whatever model your harness is driving. Scoping, architecture, design, security-
  sensitive code, review synthesis. Runs at a *high* (not maximum) effort tier for almost
  everything; the top tier is a token furnace, reserve it for one hard reasoning step.
- **`coder-low`** — a fast, cheap executor for fully-specified mechanical work (renames, schema
  fields, tests-from-pattern, translations, pre-approved plans). Decisions must be pre-named.
- **`coder-high`** — a stronger executor for semi-defined work where the approach is visible but not
  fully specified: debugging with a clear surface, style-sensitive refactors, consolidations
  needing judgment among existing patterns. Also the band for large/messy diffs even when fully
  specified — **size is the dominant quality predictor**, so a big mechanical diff still goes here,
  not to `coder-low`.
- **`advisor`** — a second-opinion consult, read-only, never edits, never blocks. See below.
- **`qa`** — a cheap model that runs the check matrix (tests, API probes, render/screenshot
  acceptance) and returns a short pass/fail report, so the lead never burns context on raw
  verification evidence.
- **`runner`** — the cheapest tier for non-intelligent work: web fetches, mechanical transforms,
  dumb sweeps. Never coding.

## Why cheap-executes / expensive-decides pays
Delegating execution keeps your expensive model's context small and its limit intact. The measured
failure mode of NOT doing this: on long sessions the lead re-reads its own bloated transcript as
cache every turn, and that re-read — not the thinking — dominates cost. Keep raw evidence
(screenshots, test logs, large file reads, verbose sub-agent transcripts) OUT of the lead: a
disposable runner turns raw → verdict and dies; the lead consumes the verdict.

## The two-stage advisor consult
A second opinion is stronger when it's genuinely independent. Run it in two sequenced stages:
1. **A different-vendor strong model answers first, cold** — the raw question, no context from your
   lead, its own original take.
2. **Your strongest reasoner then answers**, receiving the raw question *plus* stage-1's answer,
   and reaches its own best call. The one rule is anti-anchoring: don't get dragged by stage 1,
   agree only where agreement is earned. Not forced divergence, not rubber-stamping.

Surface BOTH takes to yourself, never a pre-merged verdict; then decide. Why sequenced and not two
cold parallel runs: stage 2 sees where stage 1 landed and can spend its reasoning going deeper
rather than re-deriving the obvious. Reuse ONE advisor thread per session so you pay per question,
not a full re-brief each time. Consult it (don't just push on) when: committing to non-trivial
architecture; genuinely torn between 2+ approaches; wanting a second read before locking a risky/
irreversible plan; or an "am I about to make a mistake?" gut-check on load-bearing reasoning.

## Effort discipline
Most vendors expose an effort/reasoning dial. Rule: **effort UP on cheap models, DOWN on smart
ones.** A weak model brute-forces a task with more effort; a strong model barely benefits and its
*writing* gets worse. High is the sane ceiling for almost everything; the top tier ("ultra"/"max")
is for a single genuinely hard reasoning step you'll babysit — never a blanket default, it shreds a
usage limit for little gain. Never crank effort for prose.

**Two independent cost levers — and they compound.** Cost isn't only *which* model runs the task
(route it down to a cheaper tier); it's also *how hard* your smart model thinks (run it at low
effort). These are orthogonal, so the savings stack: route the mechanical bulk to a cheap model
AND run your lead/advisor at low effort. In practice a strong model at its *lowest* effort is often
the value sweet spot — matching a pricier model at a fraction of the per-task cost — with one
caveat: low effort falls off on genuinely hard problems, which is exactly where you spend up the
dial. So default your smart tier to low/medium, reserve high+ for the hard step, and hand the
routine volume to a cheaper model entirely. Don't reach for a more expensive *model* when a cheaper
model at *higher effort*, or your smart model at *lower effort*, gets there for less.

## Cross-vendor execution (mixing Claude + another CLI)
The worked example mixes a Claude lead with OpenAI executors via the official
`openai/codex-plugin-cc` plugin (`/plugin marketplace add openai/codex-plugin-cc` →
`/plugin install`). This lets the lead hand mechanical/large work to a cheaper vendor on a separate
quota. Two rules that matter when you do this:
- **Always pass the executor's model + effort explicitly.** An unpinned call runs the vendor's
  configured default tier, not the one you intended.
- **Foreground-and-wait, never background.** A detached external worker can be reaped by the
  harness's process cleanup and wedge at "running" forever with no liveness signal. Run it in the
  foreground with an explicit timeout; it returns the result directly and can't wedge.
- **If you must background long work, watch file mtimes — not the output.** A background job's
  output file usually receives only its *final* message, so byte count ≠ liveness. The target
  files' modification times are the only true progress signal: no writes for ~15–20 min → kill it.
  **Scope the kill to that one job's process** — a broad "kill everything from this vendor" also
  destroys other sessions' running work — and **read the killed agent's final message before
  redoing**; it often holds salvageable scoping or design work.
- **Never let a delegated agent run a dev server in the foreground.** It blocks and reads as a hang.
  Every server-touching prompt says: background the server, `curl` to check it, kill it by PID.
  Foreground servers are the classic cross-vendor hang.
- **Chunk large builds; don't hand over one giant task.** Big view layers, router rewrites, anything
  that runs a server → split into 2–3 fully-specified pieces with a review checkpoint between. One
  long build is where external executors hang or silently stall.
- **Warm-thread reuse.** If an executor is continuing work it just did this session (same files),
  reuse its thread instead of re-briefing the full contract. Unrelated tasks start fresh.

## Guardrails (autonomous agents, doubly for aggressive cross-vendor ones)
- Work in git; `revert` is your disaster-recovery plan.
- Require the agent to print the exact files/targets and a delete plan before any destructive
  action.
- Strip "be persistent / thorough / clean up" language from executor prompts — that phrasing is
  what produces over-eager deletes and false "done" reports.
- Keep an automated review pass on; don't grant fully-unattended file access to an aggressive
  model.

## Review with a different model
Whoever wrote the code is the worst reviewer of it — a model is blind to its own mistakes and
reasoning gaps. Run the correctness review on a **different model, ideally a different vendor**: a
cross-model pass catches what same-model review rubber-stamps. Keep it advisory (surface findings,
you decide) and cheap — this is another place a second vendor on a separate quota earns its keep.

**Static review is only half the wall.** A reviewer *reads* code; it never *runs* the app, so it
can't see runtime or visual failures — a broken route, mobile overflow, a blank lazy-loaded section,
a placeholder that leaked through. For anything UI-affecting, get *runtime evidence*: run it,
screenshot it, look at the image. Delegate that to a runner so the screenshots never touch the
lead's context.

## Context-cost discipline (long sessions)
- **Scout-first discovery.** Open non-trivial sessions with ONE exploration brief (a file:line map,
  capped output), not a lead grep chain. The lead greps only to verify a specific claim.
- **Never full-read an unsized file.** Large file → grep for the section and read just that range,
  or take an exploration brief.
- **Cap every sub-agent's output contract** — a verbose report lands in the lead's context and is
  re-read every turn thereafter.
- **Produce skill-heavy prose artifacts in a sub-agent**, not the lead — loading heavy instructions
  into the lead puts them in the re-read loop for the rest of the session.
- **Batch shell work into a few chunky scripts**, not many small turns. Each turn re-reads the whole
  session as cache, so *turn count* — not command count — drives cost.
- **Chunk before the context wall.** Every model has a context band past which cost multiplies and
  quality rots, and some harnesses hard-cap it (and quietly move the cap). Don't lean on the maximum
  window; split long tasks before you reach it.

## The rules, and the failure each prevents
The non-obvious rules above, distilled to the lesson — not the war story that taught it:

| Rule | The failure it prevents |
|---|---|
| Delegate execution off the lead | The lead re-reads its bloated transcript as cache every turn — that re-read, not the thinking, becomes most of the bill |
| Keep raw evidence (screenshots, logs) in a runner | Image/log tokens get paid on read, then re-read every turn after — the single worst context cost |
| Foreground-and-wait for cross-vendor jobs | A backgrounded worker gets reaped and wedges at "running" forever with no liveness signal |
| Watch file mtimes, not output bytes | The output file only holds the final message, so byte growth isn't progress; a silent stall looks alive |
| Scope the kill to one job | A broad vendor-wide kill also destroys other sessions' running work |
| Read the killed agent's final message | It often holds salvageable scoping/design work you'd otherwise redo |
| Pass model + effort explicitly | An unpinned call silently runs the vendor's default tier, not the one you costed |
| Strip "be persistent / thorough" from executor prompts | Aggressive models read it as licence for over-eager deletes and false "done" reports |
| Print a delete plan before destructive actions | Otherwise you learn what it deleted after it's gone; revert is the only net |
| Chunk large builds | One giant task is where external executors hang or stall silently |
| Never foreground a dev server in a delegate | It blocks and reads as a hang — background + curl + kill by PID |
| Cross-model review | Same-model review is blind to its own mistakes |
| Effort down on smart, up on cheap | Max effort on a strong model shreds a limit for ~2 points; low effort on a weak model just fails |
| Reuse one advisor/executor thread | Re-briefing every call re-pays the full context each time |

## Routing log (starter included)
None of this is empirically tuned until you record it — and no public tool does this yet, so a
starter ships in `logger/`. Log one row per delegation and "route mechanical work to the cheap tier"
stops being an assertion; it becomes a measured fail-rate-per-dollar you can tune to *your* stack.

- **Schema** (one JSON object per line, append-only): `{ ts, task_class, role, model, effort,
  tokens, duration_s, outcome }`, where `outcome` is `pass | fail | reroute | blocker`.
- **Capture:** a `SubagentStop` hook appends a row on every delegated agent's completion — the agent
  result carries tokens + duration. See `logger/log-delegation.sh` and the wiring in
  `logger/README.md`.
- **Read it:** group by `task_class, model, effort` and watch fail-rate and tokens-per-task. Low
  fail-rate for a cheap tier on a class → push more of that class down. A spike → that's your
  escalate signal, now backed by *your* numbers instead of inherited priors.

Start logging on day one — that's how you turn these defaults into a setup tuned for your own
battlefield instead of trusting someone else's.
