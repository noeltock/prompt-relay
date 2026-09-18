<!-- prompt-relay · Codex routing profile · v4 (2026-09)
     Install only the marked policy section, following "Install shape" below.
     This template is not named AGENTS.md so editing it does not activate it. -->

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

Keep one routing policy. If a harness already owns it, merge the relevant rules into its versioned
source and use its install process. Do not append a second policy to `AGENTS.md`.

For a new global install, copy only **Model routing & delegation** (up to **Verify the roster**)
into `~/.codex/routing.md`. Add this pointer to `~/.codex/AGENTS.md`, preserving existing rules:

```markdown
Before delegating or changing a route, read `~/.codex/routing.md`; reuse it within the task unless
it changes. Simple work stays inline. Task scope, safety and proof-mode limits still apply.
```

For a project install, use `<project>/.codex/routing.md` and point to it from the project's
`AGENTS.md`. Reconcile an existing routing block rather than leaving conflicting copies. Keep
local integrations, such as GitHub writing skills, remote-host selection or Jev classification,
in the owning harness; they are not Prompt Relay prerequisites.

Merge this into the applicable config file—`~/.codex/config.toml` globally or
`<project>/.codex/config.toml` for a trusted project. Never replace an existing file:

```toml
[agents]
enabled = true
default_subagent_model = "gpt-5.6-luna"
default_subagent_reasoning_effort = "high"
max_concurrent_threads_per_session = 4
```

The default is a safety net for an untyped spawn. The named agent files are the real routing
layer. Copy [`codex-agents/`](codex-agents/) into `~/.codex/agents/`, then edit their model pins.
The shipped example roster starts bounded implementation on Luna:

| Prompt Relay role | Custom agent | Example pin | Purpose |
|---|---|---|---|
| `lead` | interactive session | your chosen lead and effort | scopes, decides, reviews, integrates |
| `coder-low` | `coder_low` | Luna, high | normal implementation after scope is clear |
| `coder-high` | `coder_high` | Terra, high | messy diffs or judgment among visible patterns |
| `advisor` | `advisor` | Astra, medium | manual second opinion; read-only |
| `qa` | `qa` | Luna, medium | executes a named check matrix; never fixes |
| `runner` | `runner` | Luna, medium | searches, transforms, fetches, and other bounded leaf work |

Model names are examples, not part of the public contract. `coder-low` means the lower coding
tier in the installed roster; it does not mean the smallest model in the catalogue. Evaluate
implementation quality on your own tasks before adopting these pins; a passing route canary
proves model selection, not coding quality or savings.

## Capability canary

Do not infer spawnability from a model name, a stale guide, or one metadata flag. Before adopting
a roster, spawn one harmless leaf canary for every model/effort pair you intend to use, then read
the resulting session transcript with `verify/check-routing-codex.sh`. A successful answer alone
is insufficient if the requested model silently fell back.

This matters on current builds: on 0.153.4, `codex debug models` reports Luna as multi-agent `v1`,
while a live v2 parent canary successfully ran Luna and its `turn_context` recorded
`gpt-5.6-luna / medium`. Runtime evidence wins over catalogue inference.

## Model routing & delegation

### Roster

The installed custom-agent names are `coder_low`, `coder_high`, `advisor`, `qa`, and `runner`.
Their TOML files own model and effort pins. Never rely on the parent model being inherited.

### Select the next action

The lead owns requirements, scope, architecture, product and security decisions, review and the
final answer. Resolve missing decisions before choosing an executor: a security-related request
does not itself authorise a coder to design the security policy. The lead settles choices from
available context and asks the user only for decisions it cannot responsibly make.

Use the table for the next action, not the eventual implementer. A file or error location bounds
the search; it does not establish the cause or fix. Apply task scope and local proof-mode limits;
delegate only when the package adds useful independent work.

| What is needed next | Route |
|---|---|
| Product, architecture, stack or security decisions; a symptom with no bounded surface | lead scopes or decides, then delegates when ready |
| Explicitly requested read-only second opinion | `advisor`; lead retains the decision |
| Obvious edits or one- or two-command checks already in context | inline |
| Bounded code diagnosis with unknown cause/fix; broad implementation search or a large/messy diff, even with a settled plan | `coder_high` |
| Otherwise, bounded code changes with a settled approach, named scope and checks, including mechanical code edits | `coder_low` |
| Execution of a named verification matrix, without fixes | `qa` |
| Bounded gathering, fetching or mechanical **non-code** transforms | `runner`; never application-code edits |

A blocker is not an automatic model promotion. Resolve the missing decision or environment issue,
then continue the same compatible worker when its role still fits. Review returned work and send
related corrections back to it. Delegation is not required on every turn or phase.

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
**🔧 Coder Low** · Dispatched: implement the approved settings change · requested Luna / high
```

When it returns, emit one line before any necessary detail:

```text
**🔧 Coder Low** · Done: settings change implemented and checks passed · verified Luna / high
```

Say `requested` until a transcript or equivalent runtime receipt establishes the actual model and
effort. Completion alone never upgrades a route to `verified`. If verification was not performed,
retain `requested`. Narrow terminals may visually wrap; do not insert a line break into the signal.

### Work-package contract

An existing issue or brief is sufficient if it supplies:

1. the outcome and acceptance criteria;
2. the exact owned files or an explicit read-only search boundary;
3. relevant context and settled decisions;
4. commands or evidence required before reporting done;
5. paths the agent must not touch;
6. a compact return contract.

Prefer `fork_turns="none"` for `runner`, `qa`, and cold `advisor` calls, then pass the bounded
package explicitly. Give a coder only the recent turns it needs. `fork_turns="none"` removes chat
history, not all inherited instructions, skills, tools or memory. Measure the effective context
before changing global settings; a small standalone CLI prompt is not proof of a small native child.
A command-only QA brief calls for its named checks, not an unrelated browser or UI audit.

Reuse an idle worker of the same role for the same project and continuing workstream after checking
host, checkout and file ownership. Follow-ups name the new scope and relevant repository changes.
Start a new worker when those no longer fit or independent work needs a separate one. A reused
worker may retain an earlier model or effort after pins change: verify its next turn before calling
it current. Reuse avoids rediscovery; it does not guarantee cache savings.

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
coder_low   gpt-5.6-luna    high
coder_high  gpt-5.6-terra   high
advisor     gpt-6-astra     medium
qa          gpt-5.6-luna    medium
runner      gpt-5.6-luna    medium
```

Add `default`, `worker` or `explorer` rules with the generic default pair if you use those roles;
an unlisted role is shown but not checked. Inspect observations after a roster change with
`--after <install-epoch-seconds>`: an older worker reused after that time still counts. No rows
means no evidence, not a passing canary.

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
