# prompt-relay

<p align="center">
  <img src="assets/hero.png" alt="A lead agent fanning work out to parallel sub-agents, each reporting its own token cost" width="100%">
</p>

**Your smartest model should be *deciding*, not *typing*.**

A copy-paste routing template for coding agents: your expensive model decides, cheap models
execute, a strong one advises. Six roles, plain markdown, no framework and nothing to install.

Paste this into your agent — it interviews you, proposes a role→model map, and installs only
after you approve:

> ```Install prompt-relay: read https://github.com/noeltock/prompt-relay/blob/main/docs/install.md, propose a role→model mapping for my stack, and install only after I confirm. Back up anything you touch; never overwrite my rules.```

## How it works
One principle: an expensive, smart model **decides** (scope, architecture, review); cheap models
**execute**; a strong one **advises** on the few hard calls. Everything routes by *role*, not by
model name, so it survives any rename or swap.

| Role | Does | Point it at |
|---|---|---|
| `lead` | scopes, decides, reviews — your session model | your best model, low effort |
| `coder-low` | fully-specified mechanical work | a cheap fast model |
| `coder-high` | messy diffs, judgment among patterns | a stronger model, higher effort |
| `advisor` | second opinion, advisory only | your strongest reasoner |
| `qa` | runs checks, reports pass/fail | a cheap model |
| `runner` | web, transforms, dumb sweeps | your cheapest |

## Start here
| Your setup | Read |
|---|---|
| **Claude Code** | [`profiles/claude-CLAUDE.md`](profiles/claude-CLAUDE.md) — paste it into your `CLAUDE.md`, edit the Roster block |
| **Codex** | [`profiles/codex-AGENTS.md`](profiles/codex-AGENTS.md) — config pins first; fan-out is on by default there, so this caps spend rather than saving it |
| **Both** | [`docs/install.md`](docs/install.md) — the mixed stack needs a wrapper agent, not a foreign model name |

Then run [`verify/`](verify/) to confirm your routing actually took effect, because the failure
mode is silent: an unpinned delegate runs the expensive model and nothing tells you.

## What else is in here
| | |
|---|---|
| `agents/` | optional named sub-agents — persistent role contracts instead of inline instructions |
| `references/routing.md` | the deep mechanics, each rule tied to the failure it prevents |
| `verify/` | reads your own logs and shows which model actually ran |
| `evals/` | 20 routing cases and 4 install scenarios, so you can test this rather than trust it |
| `docs/evidence.md` | every claim with its source and how firmly it stands |

## On being honest about savings
Delegation shrinks the bill on Claude Code because the lead re-reads its own transcript as cache
every turn, so moving execution off it is what actually saves. How much you save depends on your
caching, your session lengths and your task mix. Nobody — including us — has published a
benchmark of the delegation half, so this repo gives you the tools to measure your own numbers
instead of a headline percentage to take on faith. What's verified, what's a practitioner report
and what's still open is laid out in [`docs/evidence.md`](docs/evidence.md).
