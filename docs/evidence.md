# The evidence

Two separate questions, *does tier routing work?* and *what does delegation cost on my harness?*,
with very different amounts of evidence behind them. Sorted strongest-first, and labelled.

## Verified first-party (dated, falsifiable)

Checked directly against `codex-cli 0.152.0` on 2026-09-01, and previously against 0.145.0:
`multi_agent` ships **stable / true**: fan-out is on by default. `multi_agent_v2` exists,
stable / false. The `[agents]` config keys (`default_subagent_model`,
`default_subagent_reasoning_effort`, `max_concurrent_threads_per_session`) are present, and an
unset `default_subagent_model` inherits the lead model with no warning. `max_depth` carries the
in-binary note *"(V1 only; ignored by V2)"*, so a depth cap set under v2 does nothing.

**New at 0.152.0:** every model in the catalogue carries a `multi_agent_version` flag, readable
with `codex debug models`, and `spawn_agent` filters out anything marked `v1`. Today that reads
sol `v2`, terra `v2`, luna `v1`. That moves the practitioner report below into this section and
inverts the obvious advice: pinning the cheapest model fails *upward* to the expensive one.

**Weakened at 0.152.0:** the stop-hook payload's `model` field, verified at 0.145.0, could not be
re-confirmed by static inspection. It may still be emitted. Run a canary spawn and read your own
payload rather than trusting either answer. Method and caveats in
[`../profiles/codex-AGENTS.md`](../profiles/codex-AGENTS.md).

**Cheap-tier failure is context length, not task difficulty.** OpenAI's own MRCR v2 long-context
benchmark at 256K–512K: Sol 91.5%, Luna 41.3% (relayed by
[@MuGundo_dev](https://x.com/MuGundo_dev), 2026-08). A cheap model can be adequate on a
fully-specified task and still fail it because the repo does not fit its reliable window, and it
fails without an error. This is why `coder-low` briefs in this repo carry named files rather than
"go find where this is used".

**Unpinned defaults fail upward.** Codex CLI 0.153.4 made Astra the bundled default when no model is
configured ([@CodexReleases](https://x.com/CodexReleases/status/2096017509354778818), 2026-09-05).
An unpinned session now runs a model priced 2.5x Sol per token, with no warning. Same failure
class as the unset `default_subagent_model` above, one layer up.

**Instructions decay under volume; a mechanical gate does not.** Anthropic's study of 1,053 paid
developers: the human catch rate for a dangerous command fell from 13.6% to about 5% after 50
prompts, while a classifier held at 89% regardless of session length
([@ClaudeDevs](https://x.com/ClaudeDevs/status/2085794862608318627), 2026-08-08). The test was a
text-only simulation, nothing executed, and 89% still leaves 11% through. Uber reports the same
shape from production telemetry across 50,000+ agent sessions a day: past roughly 50 approvals a
session, oversight "becomes a rubber stamp" ([uber/ADR](https://github.com/uber/ADR),
[arXiv 2605.17380](https://arxiv.org/pdf/2605.17380v1)). Neither measures CLAUDE.md routing rules
specifically. Both measure the mechanism `hooks/claude/` relies on: a rule the model reads is a
rule that fades, a rule the harness applies is not.

**Per-task routers do not beat a simple baseline.** LLMRouterBench (400K instances, 33 models)
finds several approaches, commercial routers included, "fail to reliably outperform a simple
baseline"; "When Routing Collapses" finds routers default to the priciest model. Tiering by task
class, which is what the route table here does, is a different claim from dynamic per-task
routing, and the evidence for it is in the practitioner section.

## Reported by practitioners (reports, not benchmarks)

On Claude Code, the same architecture from a different team: [Spotify engineering, "Portal by
Spotify cut my Claude Code token usage by 90%"](https://engineering.atspotify.com/2026/9/portal-by-spotify-cut-my-claude-code-token-usage-by-90)
(2026-09). One practitioner report, not a benchmark: one Java monorepo, four scenarios, no
methodology for how the 90% was measured. Two things carry regardless. They report their
`CLAUDE.md`-only routing rules were ignored and that hook-enforced blocking is what changed
behaviour, which is the reasoning behind `hooks/claude/` here. And the 90% covers their bulk-read
pattern only (large-file reads routed through a worker), not delegation generally, so it does not
transfer to the rest of this doc. Treat it like the Codex reports below: directional, checkable,
not yet independently reproduced.

On Codex, the cost failure mode:
- [@LexnLin](https://x.com/LexnLin/status/2079073513017929918) (2026-07-20): *"Accidentally ran the
  codex goal on GPT 5.6 Sol MAX instead of medium overnight. And now I have 8% of my weekly Codex
  limit left."*
- [@dexhorthy](https://x.com/dexhorthy/status/2075805253245849872) on the trigger: *"if you even say
  the word subagent anywhere in a prompt, sol will start using subagents for everything."*
- [u/kepners](https://www.reddit.com/r/codex/comments/1v20jzo/agents_in_codex_when_running_in_max_or_pro_no/)
  (2026-07-20), on burning a 20x Max plan, and
  [u/Agreeable_Parsnip_65](https://www.reddit.com/r/codex/comments/1v3x1s4/excessive_token_consumption_resolved/)
  (2026-07-22), who fixed it with exactly the `default_subagent_model` /
  `max_concurrent_threads_per_session` pins the Codex profile recommends.
- [@evi77ain](https://x.com/evi77ain/status/2079319256492359764) (2026-07-20) reported the cheap
  tier may not be spawnable at all: *"Sol and Terra are marked as V2-compatible, while Luna, for
  some reason, is still marked as V1. So `spawn_agent` simply filters it out."* Two Reddit reports
  agreed. **Since confirmed** against 0.152.0, see the verified section above. Three consistent
  practitioner reports turned out to be right, and were checkable all along.

On the cost driver being the transcript, not the typing:
- [@dhh](https://x.com/dhh/status/2086783401445482830) (2026-08-11) published one invoice for a long
  agentic run: 59.5M cached tokens against 1.1M fresh input; the cached line was $29.73 of $42.95.
  One invoice, n=1, but it is the line item this whole repo is about.
- [@quxiaoyin](https://x.com/quxiaoyin/status/2085434860982633994) (2026-08-07), 110 sessions and
  46,580 turns self-measured: a turn after a gap over 60 minutes cost 13x a warm one (n=63); a fresh
  session with a pasted summary cost 4.5x. Unreplicated.
- [@NateBJones](https://www.youtube.com/watch?v=Y8vAQ1FgNbM) (2026-07-29): 3.77B tokens through one
  Codex workspace in a day, 3.59B of them reused input across 143 threads. Self-reported; a
  commenter notes the manual pre-work cost is not counted.

On delegation that silently lands on the expensive model:
- In the thread under [@pvncher](https://x.com/pvncher/status/2088666195381592153) (2026-08),
  @cristiancatanza instructed Sol-high to delegate to Luna-xhigh, checked the logs, and found the
  work had gone to Sol-xhigh, at 20% of a weekly quota. Two others in the thread report Sol and
  Terra not picking up Luna at all. Single accounts, unverified, and exactly what `verify/` exists
  to catch.
- Most harnesses default their auxiliary slots (compression, vision, triage) to the main model.
  Hermes exposes seven such slots, all defaulting to `auto`
  ([@Da7_Tech](https://x.com/Da7_Tech/status/2081419564051472840), 2026-08). Four practitioners
  report no measurable saving from moving them; no benchmark exists either way.

On rules in prose versus rules in hooks, from the 2026-08-03 batch of X posts:
[@andrexibiza](https://x.com/andrexibiza/status/2082151671818254800) found Hermes truncates
auto-loaded context at 20,000 characters, so the file and what the model sees drift apart
silently; [@Cryptonaut1337](https://x.com/Cryptonaut1337/status/2084004519554261232) measured
246 of 740 lines of one AGENTS.md being ignored, with an unpublished script and no replication.
Three separate authors arrived at the same fix: anything phrased "don't forget" becomes an
automation, a rule "hooked into specific tool calls" is respected where a paragraph is not.
Convergence, not measurement.

On tier routing generally: [@rasbt](https://x.com/rasbt/status/2075573860796436626): *"Use a cheap
model at higher effort — same or better performance, cheaper"*;
[@LimestoneHQ](https://x.com/LimestoneHQ/status/2076559490850165122) relaying Anthropic's
orchestrate/execute split at *96% of performance for 46% of cost*;
[@cjzafir](https://x.com/cjzafir/status/2076483843322962341) on plan/execute/review holding up over
long sessions. The strongest number is also the least portable: Cursor's own study
([cursor.com/blog/agent-swarm-model-economics](https://cursor.com/blog/agent-swarm-model-economics),
2026-07-20) put a planner/worker pair at $1,339 against $10,565 for a single frontier model on the
same work, but the worker is IDE-locked with no API, and an independent DeepSWE run scored it 16
against 64 for the frontier model. Vendor research, unreplicable by construction.

## On unbounded spawning

Sub-agents that can spawn sub-agents have produced runaway recursion in public agent frameworks,
and at least one commercial harness answers it with a hard depth cap rather than trusting
configuration. We have not reproduced an incident first-hand, so this is a design constraint, not
a measured result. The direction of the risk is not in doubt, and the mitigation (delegates are
leaves unless whitelisted) costs nothing.

## What is *not* established

These reports measure **model-tier arbitrage** (a cheaper model doing the same job), which is only
half of what this template does. Public evidence for the *delegation-architecture* half is thin, and
some of it cuts the other way: vendor cost studies are run on the vendor's own IDE-locked model and
can't be replicated externally; published router benchmarks have found routers failing to beat a
simple baseline; and a cheaper orchestrator has been observed driving workers to burn *more* total
tokens, which no routing table captures. Tools that intercept large reads and shell output report
big savings and demonstrate small ones: one such tool advertises 60–90% on bash output while its
own live demo moved a session from 3.8M to 3.7M tokens
([@EricWTech](https://www.youtube.com/watch?v=g89FJiNAlEs), 2026-07-21). The hooks in this repo
make the same kind of claim, which is why they ship with an eval that proves they fire and no
number for what they save. Treat the architecture as the durable idea and every number
here as directional.

**Including ours.** Earlier versions of this README led with a 40–60% saving. That was one
person's observation on one harness with one workload, not a benchmark, so it is gone,
replaced by `verify/`, which produces your own numbers from your own logs. If you see a headline
percentage for delegation anywhere, including here, ask what it was measured on.
