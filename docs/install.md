# Install — for an AI agent

*If you are an AI coding agent asked to "install prompt-relay", follow these steps exactly.
Do not clobber existing config; append and back up.*

**Codex-only users / agents running inside Codex: stop here.** Follow
[`../profiles/codex-AGENTS.md`](../profiles/codex-AGENTS.md) instead. Everything below installs
into `~/.claude/`, which Codex never reads, and the cost story inverts on that harness — the
profile covers the config pins, three silent-failure modes, and why the routing there caps spend
rather than saving it.

1. **Pick the target.** Ask the user: global (`~/.claude/`) or a single project (`./.claude/`)?
   Default to global if they don't care.
2. **Run the setup wizard — interview, then propose.** Don't just ask for six model names; most
   people don't know what to pick. Interview first:
   - **What do you have?** Which subscriptions / providers — Claude (Max/Pro), ChatGPT
     (Plus/Pro/Business) + Codex, Gemini, an API key, or just one of these?
   - **How do you want to run it?** Simplest (single model, no sub-agents), Claude-only multi-agent,
     or cross-vendor cost-optimized (needs two providers on separate quotas).
   - **How hands-off?** Comfortable with autonomous cross-vendor execution + guardrails, or keep it
     conservative for now?

   Then **propose a role→model mapping** from the table below that fits their access, show it back,
   and let them adjust before you write anything. `runner` defaults to their cheapest model.

   | You have | lead | coder-low | coder-high | advisor | qa | runner |
   |---|---|---|---|---|---|---|
   | **Claude only** (Max/Pro) | Opus (low) | Haiku | Sonnet (high) | Opus (high) | Haiku | Haiku |
   | **Claude + ChatGPT/Codex** | Opus (low) | Codex cheap tier | Codex mid tier (xhigh) | strong OpenAI → best Claude | Sonnet | Haiku |
   | **ChatGPT/Codex only** ([see profile](../profiles/codex-AGENTS.md)) | Sol (medium) | Luna (high) | Terra (xhigh) | Sol (high) | Luna (low) | Luna (low) |
   | **One sub / simplest** | your best model (low) | *(spawn inline)* | *(inline)* | your best (high) | your cheapest | your cheapest |
   | **API keys only** | best model (low) | cheapest capable | mid, higher effort | best (high) | cheapest | cheapest |

   Starting points, not gospel — confirm each. If they choose "simplest", skip the agent files
   (single-file mode) and stop after the core is installed.
3. **Install the routing core.** If the target `CLAUDE.md` exists, back it up
   (`CLAUDE.md.bak-<date>`) and **append** the `## Model routing & delegation` section from this
   repo's `CLAUDE.md` under a clearly-marked block — never overwrite the user's existing rules. If
   it doesn't exist, create it from this repo's `CLAUDE.md`. Fill the Roster block with the answers
   from step 2.
4. **Install the reference.** Copy `references/routing.md` to `<target>/references/routing.md`.
   Confirm the pointer at the bottom of the routing core resolves to that path.
5. **Install the agents (optional but recommended).** Copy `agents/*.md` to `<target>/agents/`.
   In each file's frontmatter, replace the `model:` placeholder with the matching answer from step
   2. If the user wants single-model mode, skip this step — the core still works inline.
6. **Cross-vendor note.** If any executor answer is a non-Claude model (e.g. an OpenAI/Codex
   model), tell the user they need the `openai/codex-plugin-cc` plugin installed, and point them at
   the "Cross-vendor execution" section of `references/routing.md`. Do NOT attempt to install that
   plugin yourself unless asked.
7. **Optional settings.** Offer to merge `settings.example.json` into `<target>/settings.json`
   (pins the `lead` model so it survives context resets). Merge, don't clobber.
8. **Optional routing log.** Offer to install `logger/` and wire the `SubagentStop` hook per
   `logger/README.md`, so the user sees their own fan-out from day one. Adjust the hook's `jq`
   field paths to the user's harness payload; don't claim it's logging until you've confirmed a row
   appends.
9. **Optional learning-loop hook.** Offer to install `learned/known-failures.md` (empty starter) and
   wire `hooks/pre-commit-checklist.sh` as a `PreToolUse` hook per `hooks/README.md`. This is the
   mechanism that turns a twice-seen fail from the routing log into a printed reminder instead of a
   third repeat — worth installing alongside the logger, not instead of it.
10. **Verify and report.** List every file created/appended with its path, echo the filled-in
   Roster table back to the user, and state which adoption tier is active (single-file vs
   agents-pack). Do not claim success for a step you skipped.

# Install — for a human

1. Copy `CLAUDE.md`'s routing section into your `~/.claude/CLAUDE.md` (or a project
   `.claude/CLAUDE.md`).
2. Edit **only the Roster block** — put your models next to each role. Everything else references
   the role, so that's the one place you touch.
3. Copy `references/routing.md` next to it (`~/.claude/references/routing.md`).
4. (Optional) Copy `agents/*.md` into `~/.claude/agents/` and set each `model:`. Skip for
   single-model mode.
5. (Optional) Merge `settings.example.json` into your `settings.json` to pin the lead model.
6. (Optional) Copy `learned/known-failures.md` and `hooks/pre-commit-checklist.sh`, then wire the
   `PreToolUse` hook per `hooks/README.md`. This is the learning-loop mechanism: a finding that
   recurs twice in the routing log gets a line here and prints before every commit from then on.

# Customising

- **Swap models:** edit the Roster block in `CLAUDE.md` and the `model:` line in each agent file.
  Nothing else references a model name.
- **Claude-only:** map `coder-low`/`coder-high` to your cheaper Claude models at rising effort;
  delete the Codex references.
- **Add a role:** give it a row in the routing table and (optionally) an `agents/<role>.md` file.
- **Trim:** the core is meant to stay lean — it loads every turn. Push detail into
  `references/routing.md`, not the core.
