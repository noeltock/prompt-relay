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

The current Codex profile uses Luna/high for bounded implementation and Sol/medium for demanding implementation; the research below describes earlier options.

### Terra for normal implementation; Luna for bounded leaves — `real signal`

OpenAI's model guidance fits the pattern, and a new community deployment skill independently maps
Luna to exact mechanical work and Terra to normal development
([Reddit, 2026-09-05](https://www.reddit.com/r/codex/comments/1w874h5/i_made_a_codex_skill_that_picks_luna_terra_sol_or/)).
The original Prompt Relay default went one step stricter: Terra-medium owned code; Luna-medium
owned runner and named QA work pending local evaluation.

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

## October 2026

Checked 2026-10-04. The earlier sections above stay as the dated record of the September roster;
this section records what changed after them.

### Verified first-party

- Claude Code has a built-in advisor tool ([docs](https://code.claude.com/docs/en/advisor.md)). It is
  enabled with `/advisor`, the `advisorModel` setting, or `--advisor`, runs server-side, and reads the
  full conversation. Claude calls it at decision points (before committing to an approach, on a
  recurring error, before declaring done). The advisor must rank at or above the main model. It bills
  to plan limits on subscriptions, except that a Fable advisor bills to usage credits on some plans.
  The same page compares it with `opusplan`, subagents and `/model`.
- [Model configuration](https://code.claude.com/docs/en/model-config.md) documents the `opusplan`
  alias (Opus in plan mode, Sonnet for execution) and `CLAUDE_CODE_SUBAGENT_MODEL`. Precedence is
  per-invocation model, then the env var, then the session model. `CLAUDE_CODE_SUBAGENT_MODEL_FORCE`
  pins all subagents, so it overrides deliberately pinned roles. Subagent frontmatter supports
  `effort` (low, medium, high, xhigh, max).
- [Sonnet 5.5](https://www.anthropic.com/claude-sonnet-5-5) released 2026-09-28 at $2/$10 per M
  tokens. Opus 5.5 released 2026-09-22. Haiku is still 4.5; a successor was announced for "coming
  weeks", which is secondary-source only.
- [GPT-6.1 Sol](https://openai.com/index/introducing-gpt-6-1-sol/) released 2026-09-22 at $2/$10
  against GPT-6 Astra at $10/$50, and is available in Codex.
- [ChatGPT Pro tiers](https://help.openai.com/en/articles/9793128-about-chatgpt-pro-tiers): on
  2026-10-30 the $200 Pro tier's Codex/Work usage drops from 20x to 10x Plus. A new Pro 500 tier adds
  Astra Ultrafast, which consumes allowance at 8x.

### Verified locally on Codex CLI 0.160.0

`codex debug models` lists `gpt-6.1-sol` as multi-agent `v2`; GPT-6 Luna and GPT-6 Sol are also
`v2`. This is catalogue inventory, not a spawnability verdict: the canary-plus-transcript rule from
the 0.153.4 section still applies. The GPT-5.6 Terra/Luna pins above are stale for new installs.

### Claude-first consolidation, with Sonnet as executor — `real signal`

X practitioners, 2026-09-20 to 2026-10-04, describe a consolidation onto Claude after Opus 5.5,
including people cancelling Codex Pro. The common setup is Opus 5.5 leading, Sonnet 5.5 executing,
and Fable advising. Anecdotes put Sonnet 5.5 high roughly level with Opus 5.5 high. Cross-vendor
survives mainly as a different-family reviewer, because heterogeneity catches different failure
modes. This is radar from posts, not a controlled comparison, and individual posts are not linked
here. It is why the shipped worked example is now Claude-only with Codex optional.

### Sonnet burns more tokens than Opus on some tasks — `too-early`

A contrarian minority reports that Sonnet sometimes spends more tokens per task than Opus, so
delegation savings on a subscription are not guaranteed. Consistent with the earlier caveat that
no savings figure ports between setups; unmeasured here.

### Advisor and router percentages — `manufactured hype`

A "79% token reduction" advisor claim has no primary source that I could find. Not Diamond's 20-65%
and Martian's "up to 97%" are vendor router claims with no frozen task set or accepted-output
grader. None transfers to a Prompt Relay roster.

### Inference, not evidence

A mid-session model switch probably cannot reuse the previous model's prompt cache. This is
inference from how prompt caching works, not something measured or documented for this case.

## What is not established

- No public controlled benchmark shows that this full routing policy beats a single strong Codex
  agent on accepted output per subscription allowance.
- No universal complexity classifier has been shown to route better than a small explicit task-class
  table for this use case.
- A successful model canary does not establish that the model is good at its assigned role.
- Transcript receipts prove route selection, not quality, elapsed-time improvement, or savings.

The next evidence step is local: freeze 10–20 representative tasks, run the proposed route and a
single-agent baseline, then record acceptance, correction turns, elapsed time, and allowance delta.
