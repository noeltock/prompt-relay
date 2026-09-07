# prompt-relay

<p align="center">
  <img src="assets/hero.png" alt="A lead agent fanning work out to parallel sub-agents, each reporting its own token cost" width="100%">
</p>

**Your smartest model should be *deciding*, not *typing*.**

A copy-paste routing template for coding agents: your expensive model decides, cheaper models
execute, a strong one advises. Six roles, plain Markdown/TOML, and no orchestration framework.

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

## What it looks like

Prompt Relay keeps runtime routing visible without turning the terminal into a dashboard. Dispatch
and completion signals are each one logical line:

> **🔧 Coder Low** · Dispatched: implement the approved settings change · requested Terra / medium

> **🔧 Coder Low** · Done: settings change implemented and checks passed · verified Terra / medium

The installer finishes with one compact roster table showing what was configured, what was
live-verified, and whether a fresh session is required. A configured route is never presented as
verified merely because its file parses.

## Start here
| Your setup | Read |
|---|---|
| **Claude Code** | [`profiles/claude-CLAUDE.md`](profiles/claude-CLAUDE.md) — paste it into your `CLAUDE.md`, edit the Roster block; optionally add [`hooks/claude/`](hooks/claude/) for enforcement |
| **Codex** | [`profiles/codex-AGENTS.md`](profiles/codex-AGENTS.md) — a model-agnostic policy plus native custom-agent TOMLs; edit the example roster for your account |
| **Both** | [`docs/install.md`](docs/install.md) — the mixed stack needs a wrapper agent, not a foreign model name |

Then run [`verify/`](verify/) to confirm your routing actually took effect, because the failure
mode is silent: requested and actual model/effort can differ unless you inspect the transcript.

## Enforcement, not just instructions
Routing rules in a `CLAUDE.md` are read, not enforced; under context pressure the lead skips them
like anything else. [`hooks/claude/`](hooks/claude/) adds the backstop for Claude Code:

- a large unscoped `Read` is blocked and redirected to a scoped read, a scout, or `bin/bulk-read`
- a bare `cat`/`head`/`tail` on a large file is blocked the same way; piped and ranged reads pass
- an unpinned `Explore`/`general-purpose` spawn *made by tool call* is pinned to your cheap model
  instead of inheriting the lead (skill- and slash-command-launched agents emit no such call — pin
  those in the skill's own frontmatter)

[`bin/bulk-read`](bin/bulk-read) is the stateless worker the deny message points to: it sends the files
plus your question to a cheap model in one shot and returns bullets, so the corpus never enters the
lead's transcript. The same shape (read gate → cheap worker) is what Spotify describes in
[their Portal write-up](https://engineering.atspotify.com/2026/9/portal-by-spotify-cut-my-claude-code-token-usage-by-90);
this version needs nothing beyond your existing CLI. Wiring is in `settings.example.json`, the
thresholds are env vars, and `evals/run-hook-evals.sh` checks all of it deterministically.

## What else is in here
| | |
|---|---|
| `agents/` | optional Claude Code sub-agents — persistent role contracts instead of inline instructions |
| `profiles/codex-agents/` | native Codex custom-agent TOMLs — example pins kept separate from the portable policy |
| `references/routing.md` | the deep mechanics, each rule tied to the failure it prevents |
| `hooks/claude/` | PreToolUse hooks that enforce the read and pin rules on Claude Code |
| `bin/bulk-read` | one-shot cross-file question to a cheap model; the corpus never touches the lead |
| `verify/` | reads your own logs and shows which model actually ran |
| `evals/` | 20 routing cases, 5 install scenarios, 17 hook cases, and Codex transcript fixtures |
| `docs/evidence.md` | every claim with its source and how firmly it stands |

## On being honest about savings
Delegation can shrink a Claude Code bill when it keeps a costly lead transcript small. On Codex,
OpenAI explicitly says subagent workflows consume more tokens than comparable single-agent runs;
the reasons to route are better context, faster independent work, and matching capability to task.
How that lands on an allowance depends on your sessions and task mix. This repo verifies the model
and effort that actually ran instead of attaching a universal percentage. What's verified, what's
a practitioner report and what's still open is in [`docs/evidence.md`](docs/evidence.md).
