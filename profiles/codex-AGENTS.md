<!-- prompt-relay · Codex routing profile · v3 (2026-09)
     Verified against current OpenAI Codex subagent documentation and codex-cli 0.153.4
     on macOS, 2026-09-06. Copy only the "Model routing & delegation" section into
     ~/.codex/AGENTS.md (global) or <repo>/AGENTS.md (project). Merge the TOML into
     ~/.codex/config.toml and copy profiles/codex-agents/*.toml into ~/.codex/agents/.

     This file is deliberately NOT named AGENTS.md. A real AGENTS.md in this template
     repository would make these installation instructions active while editing the template. -->

# Codex profile

Prompt Relay is the portable policy. Your installed roster is the local choice of models and
effort levels. Keep those layers separate: share the role contracts and route table; customize
the five small TOML files for the models your account and Codex build expose.

## What Codex gives you

Current Codex releases enable subagent workflows by default. A direct user request, an applicable
`AGENTS.md`, or a skill can ask the lead to delegate. Codex also supports named custom agents as
standalone TOML files under `~/.codex/agents/` or project-local `.codex/agents/`.

Each custom agent can pin its own `model`, `model_reasoning_effort`, sandbox, MCP servers, skills,
and instructions. This is the Codex-native equivalent of Prompt Relay's Claude agent files. Use
it instead of reducing every delegate to the built-in `worker` / `explorer` / `default` roles.

Delegation is useful for protecting the lead's context, parallelizing independent work, and
routing work to an appropriate model. It is not automatically a token saving: OpenAI states that
subagent workflows consume more tokens than comparable single-agent runs. The routing policy
therefore optimizes accepted output, elapsed time, lead-context quality, and allowance use as a
combined outcome. Measure your own workload; do not attach a universal savings percentage.

## Install shape

Merge this into the applicable config file—`~/.codex/config.toml` globally or
`<project>/.codex/config.toml` for a trusted project. Never replace an existing file:

```toml
[agents]
enabled = true
default_subagent_model = "gpt-5.6-terra"
default_subagent_reasoning_effort = "medium"
max_concurrent_threads_per_session = 4
```

The default is a safety net for an untyped spawn. The named agent files are the real routing
layer. Copy [`codex-agents/`](codex-agents/) into `~/.codex/agents/`, then edit their model pins.
The shipped example roster is intentionally conservative:

| Prompt Relay role | Custom agent | Example pin | Purpose |
|---|---|---|---|
| `lead` | interactive session | your chosen lead, medium | scopes, decides, reviews, integrates |
| `coder-low` | `coder_low` | Terra, medium | normal implementation after scope is clear |
| `coder-high` | `coder_high` | Terra, high | messy diffs or judgment among visible patterns |
| `advisor` | `advisor` | Astra, medium | manual second opinion; read-only |
| `qa` | `qa` | Luna, medium | executes a named check matrix; never fixes |
| `runner` | `runner` | Luna, medium | searches, transforms, fetches, and other bounded leaf work |

Model names are examples, not part of the public contract. `coder-low` means the lower coding
tier in the installed roster; it does not mean the smallest model in the catalogue. The default
roster keeps routine code on Terra and reserves Luna for narrow runner/QA work because current
community reports are mixed on Luna implementation quality.

## Capability canary

Do not infer spawnability from a model name, a stale guide, or one metadata flag. Before adopting
a roster, spawn one harmless leaf canary for every model/effort pair you intend to use, then read
the resulting session transcript with `verify/check-routing-codex.sh`. A successful answer alone
is insufficient if the requested model silently fell back.

This matters on current builds: on 0.153.4, `codex debug models` reports Luna as multi-agent `v1`,
while a live v2 parent canary successfully ran Luna and its `turn_context` recorded
`gpt-5.6-luna / medium`. Runtime evidence wins over catalogue inference.

## Model routing & delegation

*Install this section in the applicable `AGENTS.md`.*

### Roster

The installed custom-agent names are `coder_low`, `coder_high`, `advisor`, `qa`, and `runner`.
Their TOML files own model and effort pins. Never rely on the parent model being inherited.

### Standing routing policy

The lead owns requirements, scope, architecture, product decisions, security-sensitive judgment,
review, and the final answer. It delegates execution whenever a bounded work package can be
written without inventing a product or stack decision.

- Route ordinary coding and building with a clear goal, visible local patterns, and named
  acceptance checks to `coder_low`.
- Route large or messy diffs, debugging with a clear surface, and work requiring judgment among
  existing patterns to `coder_high`.
- Route an already-decided, named verification matrix to `qa`.
- Route read-heavy searches, mechanical transforms, fetches, and repetitive non-coding work to
  `runner`.
- Use `advisor` only when the user explicitly asks for that consult or approves it as part of the
  workflow. It is read-only and advisory.
- Keep a truly trivial change inline when it touches at most two obvious locations already in
  context. Do not spawn merely to avoid typing.

Apply this policy continuously across phases: scope once, delegate the eligible implementation,
review the returned diff/evidence, and send corrections back to the same warm agent when practical.
Continuous delegation does not mean recursive delegation or spawning on every turn.

### Relay receipts

Keep user-visible routing events compact. A dispatch and its completion are each exactly one
logical Markdown line; never expand either into a card, list, or table:

```text
**{icon} {role}** · {state}: {short task or outcome} · {routing evidence}
```

Use `🧭 Lead`, `🧠 Advisor`, `🔧 Coder Low`, `🛠️ Coder High`, `🧪 QA`, and `🔎 Runner`. The role
label carries the meaning; the icon is only a recognition aid. The allowed states are
`Dispatched`, `Done`, `Blocked`, and `Failed`.

Before a delegate starts, emit a line such as:

```text
**🔧 Coder Low** · Dispatched: implement the approved settings change · requested Terra / medium
```

When it returns, emit one line before any necessary detail:

```text
**🔧 Coder Low** · Done: settings change implemented and checks passed · verified Terra / medium
```

Say `requested` until a transcript or equivalent runtime receipt establishes the actual model and
effort. Completion alone never upgrades a route to `verified`. If verification was not performed,
retain `requested`. Narrow terminals may visually wrap; do not insert a line break into the signal.

### Route by what is missing

| Task state | Route |
|---|---|
| Goal, approach, files, and checks are clear | `coder_low` |
| Goal is clear; implementation needs local judgment | `coder_high` |
| Product, architecture, stack, or security decision is missing | lead decides or asks the user |
| A named matrix only needs to be run | `qa` |
| Bounded gathering or mechanical non-code work | `runner` |
| User requests a high-end second opinion | `advisor` |
| Two obvious edits already in context | inline |

Escalate one rung at a time: `runner` / `qa` / `coder_low` → `coder_high` → lead. A blocker is a
question to answer, not an automatic promotion. Answer it, then continue the same warm agent when
the role remains appropriate.

### Work-package contract

Every delegated brief must include:

1. the outcome and acceptance criteria;
2. the exact owned files or an explicit read-only search boundary;
3. relevant context and settled decisions;
4. commands or evidence required before reporting done;
5. paths the agent must not touch;
6. a compact return contract.

Prefer `fork_turns="none"` for `runner`, `qa`, and cold `advisor` calls, then pass the bounded
package explicitly. Give a coder only the recent turns it truly needs. Reusing a warm agent is
better than spawning a new one and rebuilding the same context.

Writing agents are sequential by default. Run them in parallel only when their file ownership is
disjoint or they have separate worktrees. Read-only agents may fan out across independent angles.
Every custom agent is a leaf (`[agents] enabled = false` in its TOML), so nested fan-out cannot
multiply unnoticed.

The custom file's sandbox is a default. Codex reapplies live sandbox/approval overrides from the
parent turn when it spawns a child. Choose the parent permission mode accordingly; keep read-only
authority in the agent instructions as a second boundary.

Every executor returns: files touched, key edits, exact commands plus exit status, and any blocker.
`qa` returns pass/fail evidence and does not fix. `runner` returns the bounded result and does not
turn a search into a redesign. Treat "standing by" or a report with no performed work as a failed
delegation.

Never let a delegate use `git checkout`, `git reset`, `git stash`, `git clean`, or revert-to-HEAD
as cleanup in a shared checkout. Pre-existing changes in an owned file are a report-and-stop
condition. Deletes follow the user's recoverable-delete policy.

### Stop conditions

The lead must stop spawning when the target is met, the requested evidence exists, a decision
requires the user, or the last two attempts made no material progress. Do not create automatic
review/fix loops. Invoke independent review at a real phase boundary and give it a finite pass.

## Verify the roster

Run a canary after installation and after model or Codex upgrades:

```bash
bash verify/check-routing-codex.sh --since 1 --roster ~/.prompt-relay-roster
```

The verifier reads Codex session transcripts directly and checks the actual model and effort from
`turn_context`. It also accepts a legacy/forwarder JSONL with `--log FILE`. Keep the roster file
simple:

```text
coder_low   gpt-5.6-terra   medium
coder_high  gpt-5.6-terra   high
advisor     gpt-6-astra     medium
qa          gpt-5.6-luna    medium
runner      gpt-5.6-luna    medium
```

Use the agent role recorded by Codex where available. If the runtime does not record a custom
role, name the spawned task with the role as its first path segment (for example,
`runner__docs_sweep`) so the transcript remains auditable.

## Finish the install

End with one compact activation receipt populated from the work actually performed:

| Role | Model / effort | Setup | Runtime proof |
|---|---|---|---|
| Lead | chosen session default | unchanged or configured | current or new task |
| Coder · low | installed route | installed or omitted | allowed proof state |
| Coder · high | installed route | installed or omitted | allowed proof state |
| Advisor · manual | installed route | installed or omitted | allowed proof state |
| QA | installed route | installed or omitted | allowed proof state |
| Runner | installed route | installed or omitted | allowed proof state |

Then list the actual files/components installed and say, in bold: **Start a new Codex task now.
This task may retain the previous model, instructions, and custom-agent registry.** `Configured`
means the setting or file exists. Allowed proof states are `live-verified`, `not invoked`,
`mismatch`, `invoked; proof unavailable`, and `failed`; only a transcript receipt earns
`live-verified`. One passing role does not verify the others. A fresh task is the clean activation
boundary; current official documentation does not promise hot reload for Codex custom-agent files.

## Status

Verified on **codex-cli 0.153.4**, macOS, 2026-09-06:

| Claim | Standing |
|---|---|
| Current Codex releases enable subagent workflows by default | official documentation |
| `AGENTS.md` or skill instructions can request delegation | official documentation |
| Custom agents live in `~/.codex/agents/` or `.codex/agents/` | official documentation |
| Custom files can pin model, effort, sandbox, MCP, skills, and instructions | official documentation |
| Explicit spawn → `[agents]` default → parent is the resolution order before custom-file overrides | official documentation |
| Subagent runs consume more tokens than comparable single-agent runs | official documentation |
| Read-heavy parallel work is the recommended starting point; concurrent writes need care | official documentation |
| Parent-turn sandbox/approval overrides can supersede a custom agent's defaults | official documentation |
| Local Luna-medium leaf canary completed and transcript recorded the requested model/effort | live local canary |
| Fresh Sol-medium session discovered custom `runner`, spawned it, and recorded `runner / Luna / medium` | live installed-role canary |
| `codex debug models` still reports Luna `v1` on the same build | live local inspection; not a spawnability verdict |
| Transcript `turn_context` records actual model and effort | live local inspection |

Re-run the canary on every version bump. Configuration is intent; the transcript is evidence.
