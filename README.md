# prompt-relay

## 💸 Same output. A fraction of the tokens.
Your smartest model should be *deciding*, not *typing*. `prompt-relay` sends the thinking
to your best model and the grunt work to cheap ones — a few copy-paste files that quietly cut
your coding-agent token bill **~40–60%** and push your usage limits hours further out. No
framework, no lock-in.

## ⚡ Get started — one paste
**New here? Paste one prompt into your coding agent and it sets up routing for your exact stack in ~2 minutes.** Drop this into Claude Code, Codex, Cursor — anything that can read a URL and write files:

```text
Install prompt-relay for me. Read the README at
https://github.com/noeltock/prompt-relay and follow its
"Install — for an AI agent" section: run the setup wizard — ask which model
subscriptions I have, how I want to run this, and which sub-agents I want —
then propose a role→model mapping and, once I confirm, install the config
into my ~/.claude/. Back up anything you touch; never overwrite my rules.
```

**What this does:** the agent interviews you — which subscriptions you have (Claude, ChatGPT/Codex, Gemini…), how hands-off you want to be, which sub-agents to wire up — then proposes a routing setup tailored to your stack (which model *decides*, which *executes*, which *reviews*) and installs it **only after you confirm**, backing up anything it touches. No framework, no account, nothing written until you approve the plan. Prefer to do it by hand? See [Install — for a human](#install--for-a-human) below.

## 🔮 Current Edge
Some of the 673+ tweets analysed:

**The labs' own benchmarks**
- **Anthropic:** *"Fable 5 orchestrates, Sonnet 5 executes — 96% of the performance for 46% of the cost."* — via [@LimestoneHQ](https://x.com/LimestoneHQ/status/2076559490850165122)
- **Anthropic (workshop):** *"We were spending $90 running agents on Opus. Sonnet 5 did the same thing for $20 — Opus-class coding at a quarter of the cost."* — via [@0xMovez](https://x.com/0xMovez/status/2077043573430636985)
- **Artificial Analysis:** the frontier models now sit on *"a new Pareto frontier of intelligence vs cost per task"* — the second-best model is a third of the price of the best. Routing is just picking your point on that curve. — [@ArtificialAnlys](https://x.com/ArtificialAnlys/status/2075268970492657905) (♥2k)
- **Cognition (Devin):** adding a cheap sidekick made it *"smarter and, surprisingly, cheaper"* — the sidekick carries context across calls so the lead never re-explains. — [@joon_h_lee](https://x.com/joon_h_lee/status/2076714221837173097) (♥811)

**The heaviest builders**
- [@rasbt](https://x.com/rasbt/status/2075573860796436626) (♥4.6k): *"Use a cheap model at higher effort — same or better performance, cheaper. Forget everything below the flagship's high tier."*
- [@cjzafir](https://x.com/cjzafir/status/2065104422762684745) (♥2.8k): *"Flagship to plan, a cheap model to execute, flagship to review. That's it. It works."* — and [48 hours on this flow, zero limit hits](https://x.com/cjzafir/status/2076483843322962341).
- [@jeffwang](https://x.com/jeffwang/status/2076770734941073911): *"Manager + cheap sidekick = flagship-level output for ~40% less than Opus 4.8."*

*The window is open right now: OpenAI just [reset all limits again at 8M users](https://x.com/thsottiaux/status/2077114635308986427) (still no 5-hour cap), and Anthropic's next flagship lands this week. Route well and you get a week of work out of a day's limits — the ones just upgrading model tiers hit the wall. This repo is that routing, ready to paste.*

> <sub>Lab-published and community-reported figures — directional, not a benchmark suite. Your
> mileage depends on your stack. The architecture below is the point; the numbers are why it caught on.</sub>

## Why this exists
- **One principle:** an expensive, smart model **decides** (scope, architecture, review); cheap
  models **execute**; a strong model **advises** on the few hard calls.
- **It's a template, not a framework.** Copy a few files, swap in your models, delete what you
  don't use. Nothing to install, nothing to import.
- **Vendor-agnostic by design.** Everything routes by *role*, not model name — so it survives any
  model rename or swap, and works Claude-only *or* mixed (e.g. Claude + OpenAI via Codex).
- **Two adoption tiers.** Works as a single copy-paste file today; scale up to named, reusable
  sub-agents when you want the full multi-agent version.
- **Keeps your best model lean.** Less raw evidence in its context = lower cost per turn and usage
  limits you hit hours later, not minutes.
- **Distilled from real use.** Pulled from a working Claude + Codex mixed stack and a review of
  production routing files — not theory.
- **It installs itself.** Hand this README to a coding agent and say *"install prompt-relay"*
  — the steps below are written for it to follow.

## What's in the box
```
prompt-relay/
├── CLAUDE.md              # the routing core — paste into your CLAUDE.md
├── references/routing.md  # deep mechanics + the hard-won rules & failure-mode table
├── agents/                # optional named sub-agents (the multi-agent tier)
│   ├── coder-low.md       # fast cheap executor — fully-specified mechanical work
│   ├── coder-high.md      # stronger executor — judgment among visible patterns
│   ├── advisor.md         # read-only second-opinion consult
│   └── qa.md              # runs your check matrix, returns a short pass/fail
├── logger/                # starter routing log — measure routing to tune it (day one)
│   ├── log-delegation.sh  # SubagentStop hook: one JSONL row per delegation
│   └── README.md          # schema, wiring, and the query that tunes your table
└── settings.example.json  # optional model pin + spawn brake
```

The **hard-won rules** — the operational intricacies of running cheap executors and cross-vendor
delegation (foreground-and-wait, scoped kills, never-foreground-a-server, cross-model review, chunk
before the wall, and more) — live in `references/routing.md`, each distilled to *the failure it
prevents* in one table. Not the war stories; the rules the war stories produced. And `logger/` ships
so you start measuring your own routing from day one instead of trusting inherited defaults.

## The roles
| Role | Does | Example model (edit) |
|---|---|---|
| `lead` | scopes, decides, reviews — your session model | Opus (low effort) |
| `coder-low` | fully-specified mechanical work | a cheap fast model (Sonnet, or a cheap Codex model) |
| `coder-high` | messy diffs, judgment among patterns | a stronger model at higher effort |
| `advisor` | second opinion, advisory only | your strongest reasoner |
| `qa` | runs tests/checks, reports pass/fail | a cheap model |
| `runner` | web / transforms / dumb sweeps | the cheapest model |

**Two adoption tiers.** The routing table works as a single file — if you never create the
`agents/*.md`, each role just means "spawn a sub-agent with this model + a one-line instruction."
Adding the agent files is an upgrade: persistent, reusable contracts.

---

## Install — for an AI agent
*If you are an AI coding agent asked to "install prompt-relay", follow these steps exactly.
Do not clobber existing config; append and back up.*

1. **Pick the target.** Ask the user: global (`~/.claude/`) or a single project (`./.claude/`)?
   Default to global if they don't care.
2. **Run the setup wizard — interview, then propose.** Don't just ask for six model names; most
   people don't know what to pick. Interview first:
   - **What do you have?** Which subscriptions / providers — Claude (Max/Pro), ChatGPT
     (Plus/Pro/Business) + Codex, Gemini, an API key, or just one of these?
   - **How do you want to run it?** Simplest (single model, no sub-agents), Claude-only multi-agent,
     or cross-vendor cost-optimized (needs two providers on separate quotas).
   - **How hands-off?** Comfortable with autonomous cross-vendor execution + guardrails, or keep it
     conservative for now?

   Then **propose a role→model mapping** from the table below that fits their access, show it back,
   and let them adjust before you write anything. `runner` defaults to their cheapest model.

   | You have | lead | coder-low | coder-high | advisor | qa | runner |
   |---|---|---|---|---|---|---|
   | **Claude only** (Max/Pro) | Opus (low) | Haiku | Sonnet (high) | Opus (high) | Haiku | Haiku |
   | **Claude + ChatGPT/Codex** | Opus (low) | Codex cheap tier | Codex mid tier (xhigh) | strong OpenAI → best Claude | Sonnet | Haiku |
   | **ChatGPT/Codex only** | best model (medium) | cheap tier (high) | mid tier (xhigh) | flagship (high) | cheap tier | cheap tier |
   | **One sub / simplest** | your best model (low) | *(spawn inline)* | *(inline)* | your best (high) | your cheapest | your cheapest |
   | **API keys only** | best model (low) | cheapest capable | mid, higher effort | best (high) | cheapest | cheapest |

   Starting points, not gospel — confirm each. If they choose "simplest", skip the agent files
   (single-file mode) and stop after the core is installed.
3. **Install the routing core.** If the target `CLAUDE.md` exists, back it up
   (`CLAUDE.md.bak-<date>`) and **append** the `## Model routing & delegation` section from this
   repo's `CLAUDE.md` under a clearly-marked block — never overwrite the user's existing rules. If
   it doesn't exist, create it from this repo's `CLAUDE.md`. Fill the Roster block with the answers
   from step 2.
4. **Install the reference.** Copy `references/routing.md` to `<target>/references/routing.md`.
   Confirm the pointer at the bottom of the routing core resolves to that path.
5. **Install the agents (optional but recommended).** Copy `agents/*.md` to `<target>/agents/`.
   In each file's frontmatter, replace the `model:` placeholder with the matching answer from step
   2. If the user wants single-model mode, skip this step — the core still works inline.
6. **Cross-vendor note.** If any executor answer is a non-Claude model (e.g. an OpenAI/Codex
   model), tell the user they need the `openai/codex-plugin-cc` plugin installed, and point them at
   the "Cross-vendor execution" section of `references/routing.md`. Do NOT attempt to install that
   plugin yourself unless asked.
7. **Optional settings.** Offer to merge `settings.example.json` into `<target>/settings.json`
   (pins the `lead` model so it survives context resets). Merge, don't clobber.
8. **Optional routing log.** Offer to install `logger/` and wire the `SubagentStop` hook per
   `logger/README.md`, so the user measures their own routing from day one. Adjust the hook's `jq`
   field paths to the user's harness payload; don't claim it's logging until you've confirmed a row
   appends.
9. **Verify and report.** List every file created/appended with its path, echo the filled-in
   Roster table back to the user, and state which adoption tier is active (single-file vs
   agents-pack). Do not claim success for a step you skipped.

## Install — for a human
1. Copy `CLAUDE.md`'s routing section into your `~/.claude/CLAUDE.md` (or a project
   `.claude/CLAUDE.md`).
2. Edit **only the Roster block** — put your models next to each role. Everything else references
   the role, so that's the one place you touch.
3. Copy `references/routing.md` next to it (`~/.claude/references/routing.md`).
4. (Optional) Copy `agents/*.md` into `~/.claude/agents/` and set each `model:`. Skip for
   single-model mode.
5. (Optional) Merge `settings.example.json` into your `settings.json` to pin the lead model.

## Customising
- **Swap models:** edit the Roster block in `CLAUDE.md` and the `model:` line in each agent file.
  Nothing else references a model name.
- **Claude-only:** map `coder-low`/`coder-high` to your cheaper Claude models at rising effort;
  delete the Codex references.
- **Add a role:** give it a row in the routing table and (optionally) an `agents/<role>.md` file.
- **Trim:** the core is meant to stay lean — it loads every turn. Push detail into
  `references/routing.md`, not the core.
