# prompt-relay

## 💸 Same output. A fraction of the tokens.
Your smartest model should be *deciding*, not *typing*. `prompt-relay` sends the thinking
to your best model and the grunt work to cheap ones — a few copy-paste files that quietly cut
your coding-agent token bill **~40–60%** and push your usage limits hours further out. No
framework, no lock-in.

## 🗓️ July 14th update — what shaped this version
The model-routing meta moved *hard* this week. v1 bakes in what people actually proved out — the
receipts:

- **"Sol plans → Luna executes → Sol reviews. 48 hours straight, zero limit hits."** — [@cjzafir](https://x.com/cjzafir/status/2076483843322962341) (♥600)
- **"Fable orchestrates, Sonnet executes: 96% of the performance at 46% of the cost."** — Anthropic's *own* numbers, via [@LimestoneHQ](https://x.com/LimestoneHQ/status/2076559490850165122)
- **"Fable 5 runs at *lower* cost per task than Opus 4.8."** — [Cognition / Devin](https://x.com/cognition/status/2076714965344342382) (♥490)
- **"Frontier model as manager + cheap sidekick = Fable-level output for ~40% less than Opus 4.8."** — [@jeffwang](https://x.com/jeffwang/status/2076770734941073911)
- **"Orchestrator + executor + 10 sub-agents in one session — ~60% fewer orchestrator tokens."** — [@sairahul1](https://x.com/sairahul1/status/2076724433293861315)
- **"Fable on *low* effort is the everyday alpha"** — matches the flagship on routine work at a fraction of the cost (spend the dial back up on genuinely hard tasks). — [@morganlinton](https://x.com/morganlinton/status/2076771596908499306) (♥89)
- **"Forget everything below the flagship's high tier — run a cheap model at higher effort. Same or better, cheaper."** — [@rasbt](https://x.com/rasbt/status/2075573860796436626) (♥4.5k)
- Same app, three ways: **Luna `$0.37` · Terra `$0.86` · Sol `$1.80`.** Pick your price. — [@melvynx](https://x.com/melvynx/status/2076667363739754647)

*The window is open right now: frontier models are briefly cheap to run and usage caps are in
flux. The people routing well are getting a week of work out of a day's limits — the ones just
upgrading model tiers are hitting the wall. This repo is that routing, ready to paste.*

> <sub>Community-reported figures from public posts — directional, not benchmarks. Your mileage
> depends on your stack. The architecture below is the point; the numbers are why it caught on.</sub>

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
| `lead` | scopes, decides, reviews — your session model | Opus / Fable |
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
2. **Gather the model choices.** Ask the user five short questions and record the answers:
   `lead`, `coder-low`, `coder-high`, `advisor`, `qa` (runner defaults to the cheapest model
   they have). If they're unsure, propose the worked example in `CLAUDE.md` and let them confirm.
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

## Credit
Distilled from a real Claude + Codex mixed-stack setup and a review of production routing files.
Adapt freely.
