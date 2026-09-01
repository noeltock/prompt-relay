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
  sensitive code, review synthesis. Runs at a *low-to-medium* effort tier by default — a strong
  model at low effort is often the value sweet spot (see Effort discipline) — reserving high for a
  genuinely hard reasoning step, and never the maximum tier as a default.
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

**That mechanism is harness-specific, and you have to check yours before assuming the saving.** The
argument above rests on two properties of the harness, not on the architecture: (1) the lead's
transcript is re-read as cache every turn, so *shrinking it* is what saves money; and (2) spawning
is explicit opt-in, so a delegation only happens when you asked for one. Claude Code has both, which
is why delegating there is a discount.

Where a harness spawns by default, or where a subagent inherits the lead's model unless you pin it,
the identical architecture inverts: every fan-out is an *additional* live model at the lead's price,
and the routing becomes a **spend ceiling** rather than a saving. Codex is the worked example — see
[`profiles/codex-AGENTS.md`](../profiles/codex-AGENTS.md) and the cross-vendor section below. The
role table, the escalation ladder, and the effort discipline all still apply; only the economics
flip. So: **never port a savings figure between harnesses**, and before assuming one, establish
which of the two properties above your harness actually has.

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

## Evidence gate on "done"
"Run the tests before reporting" is unenforced prose until the return contract requires the
evidence, not just the claim. Every executor role's report must include the exact command it ran
and its exit status (or a paste of the failing output) — not "tests: pass". If a repo has no test
or build step, that's legal too: the executor says so explicitly rather than reporting a check it
never ran. The distinction that matters is *silent absence* (claiming a check happened when it
didn't) versus *stated absence* (there's nothing to run, and it says that plainly) — only the first
is the failure mode this closes.

## Two kinds of BLOCKER
Not every blocker is the same shape, and conflating them hides the cheaper fix. Split it in two:
- **`BLOCKER: environment`** — something in the execution environment is missing or unreachable
  (no network path to a dependency, a required CLI isn't installed, a permission is denied, a
  service won't start). This is usually resolvable without a human: retry with a documented
  workaround, or escalate one rung with the specific missing capability named.
- **`BLOCKER: decision`** — a genuine product or stack choice is unmade (which library, is this a
  breaking change, does this API contract exist yet). This always goes to a human; guessing here is
  the mistake the escalation ladder exists to prevent.

Naming which kind it is changes the next move: an environment blocker is a preflight/retry problem,
a decision blocker is a stop-and-ask problem. A generic **capability preflight** — before an
executor starts, list what it actually needs (network reachability to X, a CLI on PATH, write
access to Y) and check those first — turns most `environment` blockers into a five-second check
instead of a failed run discovered the hard way. Keep the checklist itself specific to your stack
(a project's own preflight list belongs next to that project, not in this shared core); the
*pattern* — distinguish and preflight the two kinds — is what's generic here.

## Session-length circuit breaker
Chunking (below) prevents one task from ballooning; it doesn't stop a *session* from running long
after chunking should have kicked in. The long tail is real: most sessions are short, and the rare
long one can run orders of magnitude past a normal task before anyone notices. Set an explicit
stop rule and honour it: if a single session crosses a turn or token budget you've picked in
advance without hitting a natural phase boundary, stop and report rather than continuing — the
report itself (what's done, what's left, why it ran long) is more useful than another hour of
uninstrumented work. Pick the number for your own harness's context window; the rule is the
generic part, the threshold isn't.

## Cross-vendor execution (mixing Claude + another CLI)
Two directions, and they are not symmetric. Pick the one that matches which harness you actually start sessions in.

**Claude lead → OpenAI executors.** The worked example, via the official `openai/codex-plugin-cc` plugin (`/plugin marketplace add openai/codex-plugin-cc` → `/plugin install`). Note the plugin is a *Claude Code* plugin for calling out to Codex — it does not work in reverse. The rules below are written for this direction.

**The mechanism, because it is not what people expect.** A Claude Code sub-agent's `model:` field accepts Claude models only. Writing another vendor's model name there does not route to that vendor — it falls back silently, and you get a Claude model doing work you costed as cheap. Cross-vendor execution is therefore a *thin Claude wrapper that shells out*: a cheap Claude model whose entire job is to compose one self-contained prompt, run the external CLI in the foreground with model and effort passed explicitly, and return the report verbatim. `agents/coder-forwarder.example.md` is that wrapper, generic and ready to fill in. It also carries a native fallback, so an outage at the other vendor degrades to slower rather than blocked.

**Codex lead.** No plugin needed and none exists: Codex has native multi-agent (`spawn_agent`, built-in `explorer` / `worker` / `default` roles) with its own config surface. Setup, the roster mapping, which models can actually be spawned, and the silent-failure modes are in [`profiles/codex-AGENTS.md`](../profiles/codex-AGENTS.md). Read that instead of this section — most of the rules below exist to tame an *external* CLI you're shelling out to, and they don't apply when delegation is native.

One thing does carry across, inverted and worth stating plainly: **on Claude, delegation is how you save money; on Codex, delegation is what costs you money.** Codex fan-out is on by default and inherits the parent model unless pinned, so the routing there is a ceiling, not a discount. Never port a savings figure between harnesses.

Rules for the Claude-lead direction:
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

**Invoke it deliberately; never leave it always-on.** An auto-review gate that fires on every finish
can loop — the reviewer flags, the fixer changes, the reviewer flags again — and burn your quota
fast. Trigger it at real boundaries (before a commit, at the end of a phase), not as a standing hook
that re-fires on its own output.

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
| Require the command + exit status in a "done" report | "Tests: pass" with no evidence is how broken work ships as done |
| Split `BLOCKER: environment` from `BLOCKER: decision` | Conflated, the cheap fix (a missing capability) hides behind the expensive one (asking a human) |
| Set a session turn/token stop rule in advance | The long tail is the risk: a rare session runs far past where chunking should have kicked in, unnoticed until it's over |
| Name the specific actions that count as "gathering" | "It feels like judging" is how a second inspection command, a scoping grep, or reading raw sub-agent output slips onto the lead anyway |
| Make every delegate a leaf unless whitelisted | A role reachable from itself has no stopping point; nested fan-out multiplies before anyone notices |
| Ban `checkout`/`reset`/`stash`/`clean` as cleanup in shared trees | One lane's tidy-up erases every other lane's uncommitted work, silently |
| Give the cheap tier named files, never "go find it" | Cheap models degrade quietly on large context — the output stays plausible while the picture is incomplete |
| Move verbatim payloads with tools, not models | A model told not to summarise summarises anyway and reports that it didn't |
| Treat a "standing by" report as a no-op | Cheap tiers announce work they never did; counting it silently drops a whole angle |
| Verify the pin held, don't assume it | An unpinned or filtered executor fails upward to the expensive model with no error |

## The bright line: read-only gathering is legal, a second inspection chain isn't
The lead reading a file, running one command, or forming a judgement from what's already in
context is normal and correct — that's the job. What erodes the routing discipline is a *chain*:
a second inspection command run just to understand more, a grep whose purpose is to scope a spec
rather than confirm a specific claim, or parsing a sub-agent's raw output by hand instead of
reading its summary. Each one, taken alone, feels like judging. The tell that it isn't: you're
about to run something *in order to* decide what to delegate, rather than judging something a
delegate already returned. When you notice that pattern, stop and delegate the gathering itself
(a read-only exploration brief, or a verification pass) instead of doing a second round of it
yourself.

## Spawn graphs: delegates are leaves by default
An agent that can spawn agents can spawn itself. The graph doesn't have to be a straight line for
this to bite — any cycle removes the natural stopping point, and depth caps are a weaker guard than
they look because a cap set on one spawning mode is often ignored by another. Treat the ability to
spawn as a **named whitelist**, not a default: the lead can spawn, a research coordinator might be
allowed to spawn gatherers, and every other role is a leaf. Never make a role reachable from
itself, directly or through a chain.

This is not a hypothetical. Public agent frameworks have shipped recursion incidents where nested
sub-agents multiplied without bound, and at least one commercial harness answers it with a hard
depth cap rather than trusting configuration. If your harness records a spawn depth, watch it: a
depth greater than one is either something you deliberately allowed or something you didn't know
was happening.

## Several agents, one working tree
Parallel lanes in a shared checkout fail in one specific way: one agent decides to tidy up, runs
`git checkout .` or `git reset --hard`, and erases every other lane's uncommitted work. Nothing
warns anyone; the other agents keep going against files that silently reverted.

Three rules, and they belong in the brief, not in your head:
- **Name the paths.** Every brief states the files that agent owns and the paths it must not touch.
- **Ban the undo commands.** `checkout`, `reset`, `stash`, `clean`, revert-to-HEAD — all forbidden
  as a cleanup mechanism. Undo by editing forward.
- **Pre-existing changes are a stop.** If a file an agent was told to edit already has changes it
  didn't make, that's a report-and-halt, not something to merge around.

After any agent reports that it reverted something, diff the whole tree before continuing. And
when lanes are genuinely independent, give each its own worktree — isolation beats discipline.

## Transport is not judgment
Two different jobs get lumped together as "delegate the web work":
- **Judgment** — deciding what to fetch, ranking sources, choosing when to escalate to a paid
  tool. That's real work for a cheap model. Delegate it.
- **Transport** — moving a payload you need *verbatim*: a page, a thread, a document. Never route
  this through a model. Instructing a model not to summarise does not work; it will summarise and
  report that it didn't. Use a deterministic tool that writes straight to disk.

The tell is ugly: a runner reports "fetched 8/8" and every file is a paraphrase, with no error
anywhere. Re-fetching the same URLs deterministically can return several times the content. If the
payload passes through a model's context on its way to disk, assume it was compressed.

## Reading a delegate's report
- **A report with no work in it is a no-op.** "Standing by", "results will follow", "I'll begin
  shortly" — cheap tiers produce these while having done nothing. Treat them as failures and
  re-spawn; never count them toward a result.
- **Hedges survive into your synthesis.** If a delegate says "ambiguous without reading X", either
  that qualifier reaches whoever you're reporting to, or you go read X. Summarising strips
  uncertainty markers first, which is exactly how a qualified finding becomes a confident wrong
  answer two steps later.
- **A bounded search can't prove absence.** "No matches" from a scoped grep means no matches in
  that scope. Say what was actually checked, or search unscoped.

## Verify that your routing took effect
None of this is worth anything if the pins didn't hold, and the failure is silent: an unpinned
delegate runs the expensive model, does good work, and nothing anywhere says so. You find out on
the bill.

Both harnesses leave enough on disk to check. Claude Code writes a transcript per sub-agent that
records which model actually answered, at what effort, and its token usage; Codex's stop hook
reports the spawned agent's role directly. `verify/` reads whichever you have and prints a table
of role, expected model, actual model — plus a mismatch block when they disagree.

Two habits worth forming:
- **Check after every roster change.** The most common mismatch is a model name that no longer
  exists, where the harness quietly falls back instead of erroring.
- **Check what your executor can even be.** Some harnesses filter which models are eligible to run
  as a sub-agent at all, and a filtered pin fails *upward* to the expensive tier. Pinning the
  cheapest model is not the same as running it.

What this does NOT give you is cost accounting. It's a spawn-and-model audit trail: how often you
fan out, in which role, on which model. That's a smaller claim than fail-rate-per-dollar, and it's
the one the evidence on disk can actually support. Enrich it by hand with outcomes if you want the
larger one — just don't quote a number the log can't produce.

## Test the doctrine, don't trust it
`evals/` holds 20 routing cases and 4 install scenarios. Run the routing eval cold — a fresh agent,
given only the core, answering each case without the key — after any edit to your route table.
Where it disagrees, the usual cause is a genuinely ambiguous rule rather than a bad answer, and the
fix is one line in the core. Scattered misses instead of clustered ones usually mean the core isn't
being loaded at all, which is a placement problem, not a wording one.
