<!-- prompt-relay · Codex routing profile · v1 (2026-07)
     Verified against codex-cli 0.145.0. Copy the "Model routing & delegation"
     section into ~/.codex/AGENTS.md (global) or <repo>/AGENTS.md (project), and
     the TOML into ~/.codex/config.toml. Edit ONLY the Roster block.

     This file is deliberately NOT named AGENTS.md — a real AGENTS.md at any
     level of this repo would be auto-discovered by Codex as instructions for
     working ON prompt-relay, which is not what it is. -->

# Codex profile

> [!warning] Read this before enabling fan-out.
> On Codex, subagents are **not** a savings mechanism. Codex's own in-binary guidance warns they "can increase usage quickly", and the only public measurements point the same way — one user measured weekly usage going from **1% to 33% in about 25 minutes** after 20 unintended subagents spawned. The routing below exists to *cap* that, not to harvest a saving. Do not port the README's 40-60% figure to this profile; it was measured on a different harness.
>
> Worse, the off switch was reported unreliable at 0.145.0: `codex exec --disable multi_agent --disable multi_agent_v2` still ran in v2 mode and spawned subagents anyway. **Pin `default_subagent_model` before you enable anything.** An unpinned subagent inherits the lead's expensive model, which is exactly how a quota disappears in 25 minutes.

## What Codex actually gives you
Multi-agent is native and has been shipping since ~0.131. The tool the model calls is `spawn_agent`. Roles are **built-in** — `explorer`, `worker`, `default` — and those are what real sessions exercise, so this profile maps onto them rather than inventing custom role files.

Lifecycle is observable: `SubagentStart` and `SubagentStop` hook events fire. The `subagent-stop.command.input` schema carries `agent_type`, `model`, `agent_id`, `session_id`, `cwd` and `agent_transcript_path` — notably **`model`**, which is what lets you verify the pin actually held.

Given the disable flags are unreliable, **the SubagentStop logger is not optional here** — it is the only way to notice a runaway fan-out before the bill. Use [`logger/log-delegation-codex.sh`](../logger/log-delegation-codex.sh); wiring is in [`logger/README.md`](../logger/README.md). Its field paths come from the 0.145.0 schema, not from guesswork.

## Config (`~/.codex/config.toml`)
```toml
[agents]
enabled = true
default_subagent_model = "gpt-5.6-luna"        # EDIT: cheapest capable tier. NEVER leave unset.
default_subagent_reasoning_effort = "low"      # effort UP on cheap models; start low, raise on evidence
max_concurrent_threads_per_session = 4         # keep low; each thread is a live spend

[features.multi_agent_v2]
enabled = true
expose_spawn_agent_model_overrides = true      # required for per-role model routing
```

Two failure modes that are silent by design, both verified on 0.145.0:
- An invalid `model_reasoning_effort` value does **not** error. It runs. Typo it and you get the default tier while believing you pinned one.
- An unset `default_subagent_model` inherits the lead. Nothing warns you.

Verify after install rather than trusting it: run one canary task and check the `SubagentStop` log shows the `agent_role` and model you expect. Treat an install you have not seen a hook payload from as not installed.

## Model routing & delegation
*For the Codex session lead. Paste into `~/.codex/AGENTS.md`.*

**Roster → models (EDIT THIS BLOCK; everything below references the ROLE):**
| Role | Codex mapping | Notes |
|---|---|---|
| `lead` | GPT-5.6 Sol, medium effort | scopes, decides, reviews — your interactive session |
| `coder-low` | Luna, effort high | built-in role `worker`; fully-specified mechanical work |
| `coder-high` | Terra, effort xhigh | built-in role `worker` with an override; judgment among visible patterns |
| `advisor` | Sol, effort high | advisory only, never executes |
| `qa` | Luna, effort low | runs the check matrix, returns pass/fail |
| `runner` | Luna, effort low | built-in role `explorer`; web, sweeps, transforms |

Sol is the strongest and dearest, Terra the balanced middle, Luna the cheap/fast tier. Pricing is not published; positioning is from OpenAI's own material.

**Standing biases:** the `lead` scopes / decides / reviews; execution and verification delegate down. Judge the output, not the price tag — redo mediocre cheap-tier work higher up without asking. Cap every subagent's output length; turn count drives cost.

**Route by what's MISSING from the task:**
| Task class | Role | Why |
|---|---|---|
| Fully-specified, small clean diff | `coder-low` | decisions already named |
| Fully-specified but large/messy diff | `coder-high` | size predicts quality more than spec does |
| Technical judgment missing | `coder-high` | approach visible, not specified |
| Product / stack decision missing | ASK | never guess an irreversible choice |
| Choosing the approach IS the work | `lead` | design, architecture, security |
| Trivial (≤2 edits, files in context) | inline | spawn overhead > savings, and on Codex the overhead is real spend |
| Verify / QA fan-out | `qa` | never the flagship |
| Hard reasoning / second opinion | `advisor` | advisory only |
| Web / sweeps | `runner` | never coding |

**Escalation ladder:** inline → `coder-low` → `coder-high` → `lead`. One rung at a time, and only when output misses the bar on review. A `BLOCKER:` is a question to answer, not a promotion — answer it and re-spawn the same role with the decision included.

**Effort dial — wrong both ways:** max effort on Sol for routine work burns your weekly limit; default effort on Luna for a hard step just fails. Effort UP on cheap models, DOWN on smart ones. Never crank effort for writing.

**Guardrails:** work in git; require a printed file/delete plan before destructive actions; strip "be persistent / thorough / clean up" from executor prompts, which reads as licence for over-eager deletes. Pass model and effort explicitly on every call — and re-read the two silent-failure notes above, because on Codex an unpinned executor is a spend event, not just a wrong tier.

## Differences from the Claude profile
| | Claude Code | Codex |
|---|---|---|
| Delegation | Agent tool, per-agent `.md` contracts | native `spawn_agent`, built-in roles |
| Role definition | `agents/*.md` with YAML frontmatter | built-in `explorer` / `worker` / `default` |
| Config | `~/.claude/settings.json` | `~/.codex/config.toml` `[agents]` |
| Completion hook | `SubagentStop` | `SubagentStop` (payload differs) |
| Cost story | measured saving | **cost control** — no saving measured, evidence points the other way |

## Status
Verified against **codex-cli 0.145.0** on macOS. Built-in roles and `codex exec` spawning confirmed from real session records at 0.144.4. Config keys confirmed present in the binary and corroborated by two independent public reports. Custom TOML agent role files exist in the binary (`RawAgentRoleFileToml`) but their discovery path is unconfirmed — this profile deliberately sticks to built-in roles. `multi_agent_v2` exists and is off by default at 0.145.0. Re-check before bumping versions; this surface is moving.
