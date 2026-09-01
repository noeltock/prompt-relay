# Install — for an AI agent

*If you are an AI coding agent asked to "install prompt-relay", follow these steps exactly.
Do not clobber existing config; append and back up.*

**Running inside Codex, or installing for a Codex-only user?** Do step 1 and step 2 below — the
target and the interview apply to everyone — then switch to
[`../profiles/codex-AGENTS.md`](../profiles/codex-AGENTS.md) and follow it instead of steps 3
onward. Everything from step 3 installs into `~/.claude/`, which Codex never reads, and the cost
story inverts on that harness: the profile covers the config pins, which models can actually be
spawned, and why routing there caps spend rather than saving it. Two Codex-specific cautions
before you write anything: **merge into an existing `~/.codex/config.toml`, never overwrite it**
(back it up first — people keep MCP servers and other settings in there), and **run
`codex debug models` first**, because a model flagged `v1` cannot be spawned as a subagent and
pinning one silently gets you the expensive tier instead.

1. **Pick the target.** Ask the user: global (`~/.claude/`) or a single project (`./.claude/`)?
   Default to global if they don't care.

2. **Interview, then propose.** Don't just ask for six model names; most people don't know what
   to pick. Ask three things:
   - **What do you have?** Which subscriptions or providers — Claude (Max/Pro), ChatGPT
     (Plus/Pro/Business) plus Codex, an API key, or just one of these?
   - **How do you want to run it?** Simplest (single model, no sub-agents), single-vendor
     multi-agent, or cross-vendor (needs two providers on separate quotas).
   - **How hands-off?** Comfortable with autonomous execution plus guardrails, or conservative
     for now?

   **If nobody is there to answer** (you're running unattended), don't stall: write down each
   question, state the assumption you're proceeding on, install the guide's default row for their
   stack, and put the questions at the top of your final report.

   Then **propose a role→model mapping** from the table below, show it back, and let them adjust
   before you write anything.

   | You have | lead | coder-low | coder-high | advisor | qa | runner |
   |---|---|---|---|---|---|---|
   | **Claude only** | Opus (low) | Sonnet (low) | Sonnet (high) | Opus (high) | Sonnet (low) | Haiku |
   | **Claude + Codex** | Opus (low) | Codex cheap tier | Codex mid tier (xhigh) | strong OpenAI → best Claude | Sonnet | Haiku |
   | **Codex only** ([see profile](../profiles/codex-AGENTS.md)) | Sol (medium) | Terra (low) | Terra (xhigh) | Sol (high) | Terra (low) | Terra (low) |
   | **One sub / simplest** | your best model (low) | *(inline)* | *(inline)* | your best (high) | your cheapest | your cheapest |
   | **API keys only** | best model (low) | cheapest capable | mid, higher effort | best (high) | cheapest | cheapest |

   Starting points, not gospel — confirm each. Two rules that are not negotiable: **never put your
   smallest model on a coding role** (it belongs on `runner`), and if the user picks "simplest",
   skip the agent files entirely and stop after the core is installed.

3. **Install the routing core.** If the target `CLAUDE.md` exists, back it up
   (`CLAUDE.md.bak-<date>`) and **append** the `## Model routing & delegation` section from
   `profiles/claude-CLAUDE.md` under a clearly-marked block — never overwrite the user's existing
   rules. If it doesn't exist, create it. Fill in the Roster block from step 2.

4. **Install the reference.** Copy `references/routing.md` to `<target>/references/routing.md`
   and confirm the pointer at the bottom of the core resolves to it.

5. **Install the agents** (optional but recommended). Copy `agents/*.md` to `<target>/agents/`,
   then set both `model:` and `effort:` in each from step 2 — effort is half the routing design
   (up on cheap models, down on smart ones) and a file with only the model set drops that half.
   Four files ship, not six: `lead` is the session model rather than a sub-agent, and `runner` is
   deliberately inline. Add an `agents/runner.md` yourself if you'd rather have the contract.

6. **If any executor is NOT a Claude model, use the forwarder.** A sub-agent's `model:` field
   accepts Claude models only — writing another vendor's model name there does not route to that
   vendor, it silently falls back. Copy `agents/coder-forwarder.example.md` over the affected role
   file, fill in its three placeholders (`EXECUTOR-CLI`, `EXECUTOR-MODEL`, `EXECUTOR-EFFORT`),
   keep its logging step, and tell the user which external CLI it now depends on. Do
   not install that CLI yourself unless asked.

7. **Optional settings.** Offer to merge `settings.example.json` into `<target>/settings.json`.
   It contains one key, pinning the lead model so it survives context resets. Merge into the
   user's existing settings, don't clobber. If they want a hard brake on spawning, that's a
   `permissions.deny` entry — offer it only if they ask.

8. **Wire up verification.** Install `verify/` and tell the user how to run it. Note it reads
   `$HOME/.claude/projects` by default; if you installed somewhere else, set `CLAUDE_PROJECTS_DIR`
   to match or it will report on the wrong sessions. This is how they
   confirm the routing took effect, and the failure it catches is silent — an unpinned delegate
   runs the expensive model and nothing warns them. Do not claim the routing works until a run of
   `verify/check-routing.sh` shows the models they expect.

9. **Report.** List every file created or appended with its path, echo the filled-in Roster back,
   and state which tier is active (core only, or core plus agents). Do not claim success for a
   step you skipped.

# Install — for a human

1. Copy the routing section from `profiles/claude-CLAUDE.md` into your `~/.claude/CLAUDE.md` (or a
   project `.claude/CLAUDE.md`).
2. Edit the Roster block — your models next to each role. Everything else references the role.
3. Copy `references/routing.md` to `~/.claude/references/routing.md`.
4. (Optional) Copy `agents/*.md` into `~/.claude/agents/` and set each `model:`. If any executor
   isn't a Claude model, use `agents/coder-forwarder.example.md` for that role instead.
5. (Optional) Merge `settings.example.json` into your `settings.json` to pin the lead model.
6. Run `verify/check-routing.sh` after your next few delegations and check the models match your
   roster.

# Customising

- **Swap models:** edit the Roster block and the `model:` line in each agent file. Nothing else
  names a model.
- **Add a role:** give it a row in the route table and optionally an `agents/<role>.md`.
- **Trim:** the core loads every turn, so keep it lean — push detail into `references/routing.md`.
- **Check your edits still work:** `evals/` has 20 routing cases and 4 install scenarios. If your
  agent starts routing badly after a change, run the routing eval before guessing.
