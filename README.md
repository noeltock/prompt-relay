# prompt-relay

<p align="center">
  <img src="assets/hero.png" alt="A lead agent delegating work to sub-agents, each reporting its own token cost" width="100%">
</p>

**Keep your best model on the decisions that need it.**

Prompt Relay is a set of routing templates for Claude Code and Codex. The lead owns scope, architecture and review. Workers get bounded jobs, and an advisor gives a second opinion when asked. Six roles, Markdown/TOML files, and no orchestration framework to look after.

The part that's easy to miss: an agent can finish the job and still have used the wrong model. Prompt Relay checks the transcript against your roster, including workers that were already running when you changed the settings.

## Install

Paste this into your agent:

```text
Install prompt-relay: read https://github.com/noeltock/prompt-relay/blob/main/docs/install.md, propose a role→model mapping for my stack, and install only after I confirm. Back up anything you touch; never overwrite my rules.
```

The installer asks about your setup, proposes a mapping, and waits for approval. It finishes with a compact roster showing what's configured, what's been verified by a live run, and whether you need a fresh session.

| Your setup | Start here |
|---|---|
| Claude Code | [Claude profile](profiles/claude-CLAUDE.md), with optional [hooks](hooks/claude/) |
| Codex | [Codex profile](profiles/codex-AGENTS.md) and [custom-agent TOMLs](profiles/codex-agents/) |
| Both | [Installation guide](docs/install.md): Claude reaches Codex through a wrapper agent |

For Codex, keep one owned routing policy behind a conditional reference in `AGENTS.md`. The installer should fit your existing harness, not add a second set of competing rules.

## Choose the next action

A known file doesn't mean a known fix. Settle the missing decision or diagnose the cause before handing over implementation. Small command checks can stay with the lead; delegation has overhead too.

| Role | Work |
|---|---|
| `lead` | Requirements, scope, architecture, security decisions, review and integration |
| `coder-low` | Bounded implementation with a settled approach and clear acceptance |
| `coder-high` | Bounded diagnosis, large or messy diffs, judgment among existing patterns |
| `advisor` | A requested second opinion; advice only |
| `qa` | Named checks, with results and evidence; no fixes |
| `runner` | Bounded searches, fetches and non-code transforms |

The Codex example pins `coder-low` to **Luna/high**, `coder-high` to **Sol/medium**, `advisor` to **Astra/medium**, and `qa` and `runner` to **Luna/medium**. Generic Codex workers default to Luna/high. These are starting choices for an account that exposes those models, not a benchmark result.

Reuse a compatible idle worker for related work. Check its role, host, checkout and file ownership first, then verify its next observed model after changing a pin. An existing task doesn't acquire new settings just because you edited a TOML file.

## See what actually ran

Dispatch and completion each get one line:

> **🔧 Coder Low** · Dispatched: implement the approved settings change · requested Luna / high

> **🔧 Coder Low** · Done: settings change implemented and checks passed · verified Luna / high

Use **requested** until a transcript or equivalent runtime receipt proves the model and effort. A successful task alone doesn't do that.

```bash
bash verify/check-routing.sh --since 7
bash verify/check-routing-codex.sh --since 7
```

Both accept `--roster FILE`, `--after TIMESTAMP` and `--json`. Scope shared role names with `claude:` or `codex:` so one harness isn't checked against the other's model. Check coverage too: a run with no matching rules tells you very little.

Claude counts delegations. Codex counts recorded context observations, including recent turns from older workers; a later match won't hide an earlier mismatch. Neither count measures savings. The [verification guide](verify/README.md) covers roster examples, install cutoffs and receipt limits.

## Wait without guessing

For jobs tracked by the Codex companion:

```bash
bash verify/wait-on-liveness.sh --id <job-id>
```

The helper follows one job and saves its last observed turn across calls. It separates an unavailable status fetch from a valid reply showing the job has finished. Budget expiry returns “call again” only when the latest fetch was valid; an unavailable fetch returns an error.

Its stall check uses a per-turn timestamp. Set the threshold above the longest turn you expect: a quiet worker may still be working. [Exit codes and state-directory options](verify/README.md#waiting-on-a-job) are documented separately.

## Claude Code hooks

Instructions can be skipped under context pressure. The optional [PreToolUse hooks](hooks/claude/) add checks at the tool call:

- Large unscoped reads are blocked and redirected to a scoped read, a scout, or `bin/bulk-read`.
- Bare `cat`, `head` and `tail` calls on large files are blocked; piped and ranged reads pass.
- Unpinned `Explore` and `general-purpose` tool calls get your configured cheap model. Skill- and slash-command-launched agents need their own frontmatter pins.

[`bin/bulk-read`](bin/bulk-read) sends files and a question to a cheap model and returns bullets, keeping the corpus out of the lead's transcript. Spotify describes a similar read-gate-to-worker pattern in its [Portal write-up](https://engineering.atspotify.com/2026/9/portal-by-spotify-cut-my-claude-code-token-usage-by-90). This implementation uses your existing CLI. Wiring lives in `settings.example.json`; thresholds are environment variables.

## Reference and checks

| Path | Contents |
|---|---|
| `agents/` | Optional Claude sub-agents and a Codex forwarder example |
| `profiles/codex-agents/` | Native Codex leaf contracts and model pins |
| `references/routing.md` | Routing mechanics and the failures behind them |
| `verify/` | Transcript checkers and the waiting helper |
| `evals/` | 20 routing cases, 5 install scenarios, and deterministic script checks |
| `docs/evidence.md` | Sources, practitioner reports and remaining questions |

```bash
bash evals/run-claude-verifier-evals.sh
bash evals/run-codex-verifier-evals.sh
bash evals/run-liveness-evals.sh
bash evals/run-hook-evals.sh
```

These cover 10 Claude roster cases, 18 Codex verifier cases, 20 liveness cases and 17 hook cases. The fixtures check script behaviour; use a live canary to prove a model/effort pair on your installation.

## About savings

Delegation can shrink a Claude Code bill when it keeps a costly lead transcript small. On Codex, OpenAI says subagent workflows consume more tokens than comparable single-agent runs. Routing can still help with context, independent work and matching capability to the task, but the allowance impact depends on your sessions.

I wouldn't put a savings percentage on your setup without measuring it. Start with the routes that actually ran, then compare them with accepted outcomes. The [evidence notes](docs/evidence.md) separate measured results from practitioner reports.
