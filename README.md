# prompt-relay

<p align="center">
  <img src="assets/hero.png" alt="A lead agent delegating work to sub-agents, each reporting its own token cost" width="100%">
</p>

**Keep your best model on the decisions that need it.**

A handful of routing templates for Claude Code and Codex. Your lead model scopes, decides and reviews, cheaper models do the bounded work, and an advisor chimes in on the hard calls. It's all Markdown and TOML, no framework to look after.

## Where things are at (October 2026)

For a while I ran plans on Claude and pushed execution over to Codex, mostly to stretch two allowances, and I've pretty much stopped doing that. Opus 5.5 and Sonnet 5.5 handle nearly everything, Claude Code now has a built-in advisor, and OpenAI is cutting the Codex allowance on the $200 Pro plan from 20x Plus to 10x on 30 October, so there's not much quota left to play with anyway.

So the default here is Claude-only now. Codex is still handy as a reviewer (a different model family trips over different things), and if Codex is your main harness, OpenAI reckons GPT-6.1 Sol gets close to Astra at about a fifth of the price. The cross-vendor setup is still in here if you need the overflow. Sources are in [the evidence notes](docs/evidence.md), and I'll probably be rewriting this again in a month.

## Install

Paste this into your agent:

```text
Install prompt-relay: read https://github.com/noeltock/prompt-relay/blob/main/docs/install.md, propose a role→model mapping for my stack, and install only after I confirm. Back up anything you touch; never overwrite my rules.
```

It'll ask about your setup, suggest a mapping and wait for you to OK it. Or go straight to the files: the [Claude profile](profiles/claude-CLAUDE.md) (plus optional [hooks](hooks/claude/)), the [Codex profile](profiles/codex-AGENTS.md) with its [agent TOMLs](profiles/codex-agents/), or the [install guide](docs/install.md) if you want both.

## The roles

Worth trying what Claude Code already ships first: `opusplan` (Opus plans, Sonnet builds), `CLAUDE_CODE_SUBAGENT_MODEL` for any subagent you didn't pin (not the `_FORCE` one though, that overrides your pins too), and `/advisor`. That gets you a fair way, the [model config](https://code.claude.com/docs/en/model-config.md) and [advisor](https://code.claude.com/docs/en/advisor.md) docs have the details. Past that, there are six roles:

| Role | What it does | Claude | Codex |
|---|---|---|---|
| `lead` | Scope, architecture, security calls, review | Opus 5.5 / low | GPT-6.1 Sol / medium |
| `coder-low` | Bounded work, approach already settled | Sonnet 5.5 / medium | GPT-6 Luna / high |
| `coder-high` | Diagnosis, messy diffs, judgment calls | Sonnet 5.5 / high | GPT-6.1 Sol / medium |
| `advisor` | Second opinion, advice only | `/advisor` on Fable | GPT-6 Astra / medium |
| `qa` | Runs named checks, doesn't fix | Sonnet 5.5 | GPT-6 Luna / medium |
| `runner` | Searches, fetches, non-code transforms | Haiku 4.5 | GPT-6 Luna / medium |

These are my picks for October 2026, not benchmark results. One thing on Codex: keep Astra Ultrafast out of subagents, it eats your allowance at 8x.

## Checking what actually ran

Model pins fail quietly, a delegate runs on the wrong model, does decent work and nobody notices. So every dispatch gets a one-line receipt, and it stays "requested" until a transcript proves the model and effort:

> **🔧 Coder Low** · Done: settings change implemented and checks passed · verified Sonnet 5.5 / medium

```bash
bash verify/check-routing.sh --since 7
bash verify/check-routing-codex.sh --since 7
```

Both take `--roster FILE` to check against your own mapping. The rest (roster formats, cutoffs, waiting on long Codex jobs) is in the [verification guide](verify/README.md).

## Hooks, bulk reads and evals

On Claude Code, the optional [hooks](hooks/claude/) stop big unscoped reads landing in the lead's context and pin unpinned `Explore`/`general-purpose` spawns to your cheap model. [`bin/bulk-read`](bin/bulk-read) is the way around it: files plus a question go to a cheap model and you get bullets back (Spotify wrote up the same idea in their [Portal post](https://engineering.atspotify.com/2026/9/portal-by-spotify-cut-my-claude-code-token-usage-by-90)).

The evals cover 10 Claude verifier cases, 18 Codex verifier, 20 liveness and 17 hook cases, plus 20 routing cases and 5 install scenarios. They test the scripts rather than your models, so you'll still want one live canary after installing.

```bash
for f in evals/run-*-evals.sh; do bash "$f"; done
```

## Does it save anything?

It can cut a Claude Code bill by keeping the lead's transcript small, but that's about as far as I'd go. OpenAI says Codex subagents use more tokens than a single agent, and a few people report Sonnet burning more tokens than Opus on the same task. The big savings percentages going around on X mostly have no control behind them, so I'm not quoting one. Check what actually ran, compare it to the work you kept, and go from there.
