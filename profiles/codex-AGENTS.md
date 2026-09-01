<!-- prompt-relay · Codex routing profile · v2 (2026-09)
     Verified against codex-cli 0.152.0 on macOS, 2026-09-01. Copy the "Model routing & delegation"
     section into ~/.codex/AGENTS.md (global) or <repo>/AGENTS.md (project), and
     the TOML into ~/.codex/config.toml. Edit ONLY the Roster block.

     This file is deliberately NOT named AGENTS.md — a real AGENTS.md at any
     level of this repo would be auto-discovered by Codex as instructions for
     working ON prompt-relay, which is not what it is. -->

# Codex profile

> [!warning] Read this before enabling fan-out.
> On Codex, subagents are **not** a savings mechanism. `multi_agent` ships **stable / true** at 0.145.0 — fan-out is on by default — and an unpinned subagent inherits the lead's model silently. The public reports run the same direction: users burning a 20x Max plan ([u/kepners](https://www.reddit.com/r/codex/comments/1v20jzo/agents_in_codex_when_running_in_max_or_pro_no/), 2026-07-20), a weekly limit down to 8% from one accidental Max-effort overnight run ([@LexnLin](https://x.com/LexnLin/status/2079073513017929918)), and the trigger being as light as the word itself — *"if you even say the word subagent anywhere in a prompt, sol will start using subagents for everything"* ([@dexhorthy](https://x.com/dexhorthy/status/2075805253245849872)). No measured saving on this harness exists publicly, and nothing in the README's Claude-side reasoning carries over — the cache and spawn behaviour are different. The routing below exists to *cap* spend, not to harvest a saving.
>
> Worse, the off switch was reported unreliable at 0.145.0: `codex exec --disable multi_agent --disable multi_agent_v2` still ran in v2 mode and spawned subagents anyway. **Pin `default_subagent_model` before you enable anything.** An unpinned subagent inherits the lead's expensive model, which is exactly how a quota disappears in 25 minutes.

## What Codex actually gives you
Multi-agent is native and has been shipping since ~0.131. The tool the model calls is `spawn_agent`. Roles are **built-in** — `explorer`, `worker`, `default` — and those are what real sessions exercise, so this profile maps onto them rather than inventing custom role files.

Lifecycle is observable: `SubagentStart` and `SubagentStop` hook events fire. The `subagent-stop.command.input` schema carries `agent_type`, `model`, `agent_id`, `session_id`, `cwd` and `agent_transcript_path` — notably **`model`**, which is what lets you verify the pin actually held.

Given the disable flags are unreliable, **wire the SubagentStop logger before you enable anything** — a completed fan-out leaves a row, which is how you catch a runaway pattern early rather than on the bill. Use [`verify/log-delegation-codex.sh`](../verify/log-delegation-codex.sh) and read it with `verify/check-routing-codex.sh`; wiring is in [`verify/README.md`](../verify/README.md). Note the honest limit: the hook fires on completion, so a delegate you kill mid-run writes nothing. It catches the pattern, not every individual event.

## Config (`~/.codex/config.toml`)
```toml
[agents]
enabled = true
default_subagent_model = "gpt-5.6-terra"       # EDIT: cheapest model marked v2 in `codex debug models`.
                                               # NEVER leave unset, and never pin a v1-flagged model —
                                               # spawn_agent filters those and falls back UP to the lead.
default_subagent_reasoning_effort = "low"      # effort UP on cheap models; start low, raise on evidence
max_concurrent_threads_per_session = 4         # keep low; each thread is a live spend

[features.multi_agent_v2]
enabled = true
expose_spawn_agent_model_overrides = true      # required for per-role model routing
```

Three failure modes that are silent by design, all verified against 0.145.0:
- An invalid `model_reasoning_effort` value does **not** error. It runs. Typo it and you get the default tier while believing you pinned one.
- An unset `default_subagent_model` inherits the lead. Nothing warns you.
- `max_depth` is annotated in the binary as **"(V1 only; ignored by V2)"**. If you've enabled `multi_agent_v2` and set a depth cap expecting it to bound recursive spawning, it does nothing.

**Your cheap tier may not be spawnable — check before you pin it.** Every model in the catalogue carries a `multi_agent_version` flag, and `spawn_agent` filters out anything still marked `v1`. This was three people's report in July; at 0.152.0 it is directly queryable:

```
codex debug models        # read-only; inspect multi_agent_version per model
```

At 0.152.0 that returns `gpt-5.6-sol → v2`, `gpt-5.6-terra → v2`, **`gpt-5.6-luna → v1`** — confirming [@evi77ain](https://x.com/evi77ain/status/2079319256492359764)'s account exactly, alongside [u/wenicud](https://www.reddit.com/r/codex/comments/1v26ebx/56sol_unable_to_spawn_56luna_subagents/) and [u/kepners](https://www.reddit.com/r/codex/comments/1v20jzo/agents_in_codex_when_running_in_max_or_pro_no/).

**This inverts the obvious advice.** Pinning the cheapest model as your default subagent looks like the safe move and is currently the opposite: a filtered pin fails *upward*, silently, to the expensive model — the exact outcome this profile exists to prevent. Until the cheap tier is flagged `v2`, pin the cheapest model that IS `v2` (Terra today) and keep genuinely trivial work inline rather than spawning it. Run `codex debug models` on your own build before trusting any roster below; these flags move between releases.

Verify after install rather than trusting it: run one canary task and check the `SubagentStop` log shows the `agent_role` and model you expect. Treat an install you have not seen a hook payload from as not installed.

## Model routing & delegation
*For the Codex session lead. Paste into `~/.codex/AGENTS.md`.*

**Roster → models (EDIT THIS BLOCK; everything below references the ROLE):**
| Role | Codex mapping | Notes |
|---|---|---|
| `lead` | GPT-5.6 Sol, medium effort | scopes, decides, reviews — your interactive session |
| `coder-low` | Terra, effort low | built-in role `worker`; fully-specified mechanical work |
| `coder-high` | Terra, effort xhigh | built-in role `worker` with an override; judgment among visible patterns |
| `advisor` | Sol, effort high | advisory only, never executes |
| `qa` | Terra, effort low | runs the check matrix, returns pass/fail |
| `runner` | Terra, effort low | built-in role `explorer`; web, sweeps, transforms |

Sol is the strongest and dearest, Terra the balanced middle, Luna the cheap/fast tier. Pricing is not published; positioning is from OpenAI's own material.

**Why Luna appears nowhere in that roster.** It is the model you would want for the cheap rows, and at 0.152.0 it cannot be spawned as a subagent at all — see the `multi_agent_version` note above. The cheap rows therefore separate by *effort* on Terra rather than by model. Re-run `codex debug models` after any upgrade: the day Luna flips to `v2`, move `coder-low`, `qa` and `runner` onto it and this profile gets meaningfully cheaper.

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
Verified against **codex-cli 0.152.0** on macOS, re-checked 2026-09-01 (previously 0.145.0, 2026-07-28). Every row below was re-run against the current binary.

| Claim | Standing |
|---|---|
| `multi_agent` stable / true (fan-out on by default) | **verified** — `codex features list` |
| `multi_agent_v2` exists, stable / false | **verified** — same |
| `[agents]` keys + `expose_spawn_agent_model_overrides` present | **verified** — present in binary |
| `max_depth` annotated "(V1 only; ignored by V2)" | **verified** — in-binary string |
| Unset `default_subagent_model` inherits the lead | **verified** — documented behaviour, no warning emitted |
| Built-in roles `explorer` / `worker` / `default`; tool is `spawn_agent` | **verified** — `spawn_agent` in binary; roles confirmed from real session records at 0.144.4 |
| `subagent-stop` payload carries `agent_type` / `agent_id` / `session_id` / `cwd` / `agent_transcript_path`, no tokens or duration | **verified** at 0.152.0 |
| …and that the payload still carries `model` | **UNCONFIRMED at 0.152.0** — verified at 0.145.0, but `model` no longer appears alongside the payload's other field names in the binary. It may simply live elsewhere; static inspection can't settle it. Run one canary spawn and read your own hook payload. If `model` is genuinely gone, the pin-verification method below loses its evidence and `verify/check-routing-codex.sh` will report that column as unavailable rather than guess. |
| Cheap tier filtered out of `spawn_agent` by V1/V2 model flags | **verified** at 0.152.0 — `codex debug models` shows `multi_agent_version` per model: sol `v2`, terra `v2`, luna `v1`. Upgraded from "reported only" |
| Custom TOML role files (`RawAgentRoleFileToml`, `AgentRole` with `config_file`) | **present, discovery path unconfirmed** — this profile sticks to built-in roles |
| `--disable multi_agent --disable multi_agent_v2` unreliable | **reported only** — single public report at 0.145.0, not reproduced here |

Re-check on every version bump; this surface is moving fast. Anything marked *reported only* is one person's experience until you've seen it yourself — the hook payload is how you check.
