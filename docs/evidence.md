# The evidence

Two separate questions — *does tier routing work?* and *what does delegation cost on my harness?* —
with very different amounts of evidence behind them. Sorted strongest-first, and labelled.

## Verified first-party (dated, falsifiable)

Checked directly against `codex-cli 0.145.0`:
`multi_agent` ships **stable / true** — fan-out is on by default. `multi_agent_v2` exists,
stable / false. The `[agents]` config keys (`default_subagent_model`,
`default_subagent_reasoning_effort`, `max_concurrent_threads_per_session`) are present, and an
unset `default_subagent_model` inherits the lead model with no warning. `max_depth` carries the
in-binary note *"(V1 only; ignored by V2)"* — a depth cap set under v2 silently does nothing.
Re-check on version bumps; this surface moves. Method and caveats in
[`../profiles/codex-AGENTS.md`](../profiles/codex-AGENTS.md).

## Reported by practitioners (not benchmarks — reports)

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
- [@evi77ain](https://x.com/evi77ain/status/2079319256492359764) (2026-07-20) reports the cheap tier
  may not be spawnable at all: *"Sol and Terra are marked as V2-compatible, while Luna, for some
  reason, is still marked as V1. So `spawn_agent` simply filters it out."* Two Reddit reports agree.
  **Unconfirmed against the binary** — if it holds, pin a tier that actually spawns and check the log.

On tier routing generally: [@rasbt](https://x.com/rasbt/status/2075573860796436626) — *"Use a cheap
model at higher effort — same or better performance, cheaper"*;
[@LimestoneHQ](https://x.com/LimestoneHQ/status/2076559490850165122) relaying Anthropic's
orchestrate/execute split at *96% of performance for 46% of cost*;
[@cjzafir](https://x.com/cjzafir/status/2076483843322962341) on plan/execute/review holding up over
long sessions.

## What is *not* established

These reports measure **model-tier arbitrage** (a cheaper model doing the same job) — which is only
half of what this template does. Public evidence for the *delegation-architecture* half is thin, and
some of it cuts the other way: vendor cost studies are run on the vendor's own IDE-locked model and
can't be replicated externally; published router benchmarks have found routers failing to beat a
simple baseline; and a cheaper orchestrator has been observed driving workers to burn *more* total
tokens, which no routing table captures. Treat the architecture as the durable idea and every number
here as directional.
