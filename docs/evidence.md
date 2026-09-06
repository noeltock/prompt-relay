# The evidence

Prompt Relay separates three questions that are often collapsed into one:

1. Can the harness route a named role to a specific model and effort?
2. Does that role produce acceptable work on your task distribution?
3. Does the complete workflow improve elapsed time, allowance use, correction time, or lead-context
   quality?

The first can be proven from configuration and transcripts. The second and third require local
evals. A social post or vendor price table cannot answer them for your repository.

## Verified first-party

As of 2026-09-06, [OpenAI's Codex subagent documentation](https://learn.chatgpt.com/docs/agent-configuration/subagents)
states that:

- current Codex releases enable subagent workflows by default;
- a direct request, applicable `AGENTS.md`, or skill instruction can trigger delegation;
- local Codex supports named custom agents in `~/.codex/agents/` or `.codex/agents/`;
- custom TOMLs can set model, reasoning effort, sandbox, MCP servers, skills, and instructions;
- an explicit spawn, `[agents]` defaults, and the parent determine model/effort before custom-file
  overrides are applied;
- subagent workflows consume more tokens than comparable single-agent runs;
- read-heavy exploration, tests, triage, and summarization are the recommended starting point for
  parallelism, while concurrent write-heavy workflows need more care;
- Terra is positioned for efficient read-heavy/parallel work and Luna for clear, repeatable,
  high-volume leaf work.

The [Codex configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference)
documents global `~/.codex/config.toml`, trusted-project `.codex/config.toml`, `agents.enabled`,
`agents.default_subagent_model`,
`agents.default_subagent_reasoning_effort`, `agents.max_concurrent_threads_per_session`, and custom
role declarations.

The [current model catalogue](https://developers.openai.com/api/docs/models/all) positions Astra as
the strongest tier, Terra as the intelligence/cost balance, and Luna as the cost-sensitive,
high-volume tier. Those are capability starting points, not proof that a particular route is good.

For cross-vendor evidence, OpenAI's [non-interactive mode documentation](https://learn.chatgpt.com/codex/non-interactive-mode)
states that `codex exec --json` emits a JSONL event stream including
`thread.started.thread_id`. The [Codex command reference](https://learn.chatgpt.com/codex/developer-commands?surface=cli)
documents exact-ID `codex archive <session-id>`, and the [hooks reference](https://learn.chatgpt.com/codex/hooks)
documents the active model slug and transcript path in hook input. Prompt Relay uses the emitted
thread ID to avoid associating or archiving concurrent sessions by timestamp. Requested CLI flags
remain intent; only an observed hook/transcript field counts as routing evidence.

## Verified locally on Codex CLI 0.153.4

Checked on macOS, 2026-09-06:

- The canary parent used a Sol-medium lead with a Terra-medium default subagent. The global lead
  default has since changed; the transcript receipt, not today's config, is the evidence for that
  historical run.
- `codex debug models` reports Astra/Sol/Terra as multi-agent `v2` and Luna as `v1`.
- A live v2-parent canary explicitly requested `gpt-5.6-luna / medium` and completed.
- Its subagent transcript `turn_context` recorded `model: gpt-5.6-luna` and
  `reasoning_effort: medium`.
- After installing the custom TOMLs, a fresh Sol-medium CLI session discovered `runner`, spawned
  `runner__installed_canary`, and the child transcript recorded `agent_role: runner`, Luna, medium.
- `verify/check-routing-codex.sh` matched that live row against the installed roster with no
  mismatch.
- The same transcript identifies the parent thread and agent path.

This contradiction is operationally useful: a catalogue protocol flag is not a reliable
spawnability verdict on its own. Prompt Relay therefore requires a harmless canary plus transcript
inspection after install and upgrades. `verify/check-routing-codex.sh` automates that inspection.

## Current practitioner signal

Community evidence is radar, not authority. The August–September 2026 signal is strong enough to
shape the default, but not to justify a savings claim.

### Named role files plus a strong lead — `real signal`

A highly discussed August setup uses a strong lead with packaged Luna/Terra workers and explicit
role files ([Reddit, 2026-08-16](https://www.reddit.com/r/codex/comments/1vptjhb/300m_tokens_only_50_weekly_limit_burned_heres_how/)).
Another thread describes the same small-work-package pattern and keeping a stronger fallback
([Reddit, 2026-08-01](https://www.reddit.com/r/codex/comments/1vcrwsi/for_those_who_dont_know_how_to_set_up_sol/)).
OpenAI now documents this exact custom-agent mechanism. The structure is real; the reported
allowance savings remain self-reported.

Signals: persistence ✓ · velocity ✓ · credibility ✓ · corroboration ✓.

### Terra for normal implementation; Luna for bounded leaves — `real signal`

OpenAI's model guidance fits the pattern, and a new community deployment skill independently maps
Luna to exact mechanical work and Terra to normal development
([Reddit, 2026-09-05](https://www.reddit.com/r/codex/comments/1w874h5/i_made_a_codex_skill_that_picks_luna_terra_sol_or/)).
The conservative Prompt Relay default goes one step stricter: Terra-medium owns code; Luna-medium
owns runner and named QA work until local evals promote it.

Signals: persistence ✓ · velocity ✓ · credibility ✓ · corroboration ✓.

### Luna as the general implementation tier — `too-early`

Positive reports exist, including multi-hour frontend work
([Reddit, 2026-08-03](https://www.reddit.com/r/codex/comments/1veqtnq/delegating_tasks_from_sol_to_luna_subagents_is/)).
Recent counter-reports say Luna implementation can create correction loops and that production code
should stay on Terra or above
([Reddit, 2026-09-05](https://www.reddit.com/r/codex/comments/1w7wlsv/sub_agents/),
[Reddit, 2026-08-04](https://www.reddit.com/r/codex/comments/1vezss6/sol_plans_luna_executes_a_practical_skill_to_save/)).
Task and repository shape appear decisive; no controlled comparison settles it.

Signals: persistence ✓ · velocity ✓ · credibility ✓ · corroboration ✗ (outcomes conflict).

### Universal delegation savings percentages — `manufactured hype`

The loudest posts publish token or allowance totals without a frozen task set, accepted-output
grader, correction cost, or single-agent control. OpenAI explicitly says subagent workflows consume
more tokens. Any percentage may describe one person's subscription workload, but it does not
transfer as a Prompt Relay claim.

Signals: persistence ✓ · velocity ✓ · credibility ✗ · corroboration ✗.

## Claude-specific evidence

Claude Code and Codex do not share an enforcement surface. Prompt Relay's Claude read guards and
model-pin hooks remain useful on Claude Code because they can mechanically intercept selected tool
calls. Codex routing now uses native custom-agent config plus transcript verification. Do not copy a
Claude hook merely because the role policy is shared.

Spotify's Portal write-up is still useful directional evidence for moving bulk reads out of a lead
context: [Portal by Spotify](https://engineering.atspotify.com/2026/9/portal-by-spotify-cut-my-claude-code-token-usage-by-90)
(2026-09). Its headline covers their Java-monorepo bulk-read workflow, not delegation generally.

## What is not established

- No public controlled benchmark shows that this full routing policy beats a single strong Codex
  agent on accepted output per subscription allowance.
- No universal complexity classifier has been shown to route better than a small explicit task-class
  table for this use case.
- A successful model canary does not establish that the model is good at its assigned role.
- Transcript receipts prove route selection, not quality, elapsed-time improvement, or savings.

The next evidence step is local: freeze 10–20 representative tasks, run the proposed route and a
single-agent baseline, then record acceptance, correction turns, elapsed time, and allowance delta.
