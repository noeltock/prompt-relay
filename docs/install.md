# Install — for an AI agent

*If you are an AI coding agent asked to "install prompt-relay", follow these steps exactly.
Do not clobber existing config; append and back up.*

The tool running this installer does not determine the installation target. A Codex agent can
configure Claude Code, and a Claude agent can prepare a Codex install. Complete steps 1 and 2 first,
then follow every approved host path:

- **Codex:** follow [`../profiles/codex-AGENTS.md`](../profiles/codex-AGENTS.md). Merge into an
  existing `~/.codex/config.toml` for global scope or `<project>/.codex/config.toml` for project
  scope; never replace it. The profile owns its Codex receipt.
- **Claude Code:** continue with steps 3–10 below.
- **Both:** complete the Codex setup but defer its standalone receipt, continue through steps 3–10,
  then produce one combined receipt with an activation instruction for each host.

For Codex, prove each model/effort pair with a live canary plus
`verify/check-routing-codex.sh`. `codex debug models` is useful inventory, but current builds can
successfully run a Luna leaf even while its catalogue row says `v1`; runtime evidence wins.

1. **Pick hosts and scope.** Ask which host or hosts to configure: Codex, Claude Code, or both.
   For each selected host, ask for global or single-project scope. Claude uses `~/.claude/` or
   `<project>/.claude/`; Codex uses `~/.codex/agents/` or `<project>/.codex/agents/`, with routing
   policy in the applicable `CLAUDE.md` or `AGENTS.md`. Default to global only if they do not care.

2. **Interview, then propose.** Don't just ask for six model names; most people don't know what
   to pick. Ask three things:
   - **What do you have?** Which subscriptions or providers — Claude (Max/Pro), ChatGPT
     (Plus/Pro/Business) plus Codex, an API key, or just one of these?
   - **How do you want to run it?** Simplest (single model, no sub-agents), single-vendor
     multi-agent, or cross-vendor (needs two providers on separate quotas).
   - **How hands-off?** Comfortable with autonomous execution plus guardrails, or conservative
     for now?

   **If nobody is there to answer** (you're running unattended), prepare the recommended default
   row, write down the unanswered questions and assumptions, and stop before changing files. Only
   proceed unattended when the task brief already names or explicitly authorizes that roster; a
   generic request to inspect or propose Prompt Relay is not approval to install defaults.

   Then **propose a role→model mapping** from the table below, show it back, and let them adjust
   before you write anything.

   | You have | lead | coder-low | coder-high | advisor | qa | runner |
   |---|---|---|---|---|---|---|
   | **Claude only** | Opus (low) | Sonnet (low) | Sonnet (high) | Opus (high) | Sonnet (low) | Haiku |
   | **Claude + Codex** | Opus (low) | Codex cheap tier | Codex mid tier (xhigh) | strong OpenAI → best Claude | Sonnet | Haiku |
   | **Codex only** ([see profile](../profiles/codex-AGENTS.md)) | chosen lead (medium) | Terra (medium) | Terra (high) | Astra (medium, manual) | Luna (medium) | Luna (medium) |
   | **One sub / simplest** | your best model (low) | *(inline)* | *(inline)* | your best (high) | your cheapest | your cheapest |
   | **API keys only** | best model (low) | cheapest capable | mid, higher effort | best (high) | cheapest | cheapest |

   Starting points, not gospel — confirm each. Keep the smallest model on bounded runner/QA work
   until local evals earn it a coding role.

   If the user picks **simplest**, do not install either multi-agent profile or any agent files,
   forwarders, hooks, or agent defaults. Append only this marked host-appropriate policy, then skip
   steps 3–9 and complete the receipt in step 10:

   ```markdown
   ## Prompt Relay — single-agent mode

   Work entirely in the active session. Do not spawn subagents or forward work to another CLI.
   The session owns scope, implementation, verification, and the final answer. Report this as
   `single-agent core` in the installation receipt.
   ```

3. **Install the routing core.** If the target `CLAUDE.md` exists, back it up
   (`CLAUDE.md.bak-<date>`) and **append** the `## Model routing & delegation` section from
   `profiles/claude-CLAUDE.md` under a clearly-marked block — never overwrite the user's existing
   rules. If it doesn't exist, create it. Fill in the Roster block from step 2.

4. **Install the reference.** Copy `references/routing.md` to `<target>/references/routing.md`
   and confirm the pointer at the bottom of the core resolves to it.

5. **Install the agents** (optional but recommended). Copy `agents/advisor.md`,
   `agents/coder-low.md`, `agents/coder-high.md`, and `agents/qa.md` to `<target>/agents/`,
   then set both `model:` and `effort:` in each from step 2 — effort is half the routing design
   (up on cheap models, down on smart ones) and a file with only the model set drops that half.
   Four files ship, not six: `lead` is the session model rather than a sub-agent, and `runner` is
   deliberately inline. Add an `agents/runner.md` yourself if you'd rather have the contract.

6. **If any executor is NOT a Claude model, use the forwarder.** A sub-agent's `model:` field
   accepts Claude models only — writing another vendor's model name there does not route to that
   vendor, it silently falls back. Copy `agents/coder-forwarder.example.md` over the affected role
   file, set its frontmatter `name:` for the affected role, and fill in its four placeholders
   (`FORWARDER-ROLE`, `EXECUTOR-CLI`, `EXECUTOR-MODEL`, `EXECUTOR-EFFORT`),
   keep its logging step, and tell the user which external CLI it now depends on. Do
   not install that CLI yourself unless asked.

7. **Optional settings.** Offer to merge `settings.example.json` into `<target>/settings.json`.
   It pins the lead model so it survives context resets, plus (if step 8 was taken) the `env` and
   `hooks` blocks that wire the enforcement layer in. Merge into the user's existing settings,
   don't clobber. If they want a hard brake on spawning, that's a `permissions.deny` entry — offer
   it only if they ask.

8. **Enforcement (Claude Code only, optional).** The routing core is markdown the lead *reads* —
   under context pressure it can skip a rule the same way it skips anything else. Hooks are
   *enforced* by the harness, not read by the model. Offer this to anyone who wants the backstop,
   not just the honor system:
   - Copy `hooks/claude/` to `~/.claude/hooks/prompt-relay/` (or `<target>/hooks/prompt-relay/`
     for a project install) and `chmod +x` the three `.sh` files.
   - Copy `bin/bulk-read` to `~/.claude/bin/bulk-read` and `chmod +x` it; make sure that directory
     is on `PATH` (or tell the user to add it) so the hooks' own deny messages resolve.
   - Merge the `env` and `hooks` blocks from `settings.example.json` into `<target>/settings.json`
     (see step 7), updating the hook `command` paths if you installed anywhere other than
     `~/.claude/`.
   - Read `hooks/claude/README.md` before installing — it has the full behaviour, the exact
     `settings.json` snippet, and what the hooks do *not* catch (Codex is unaffected; the Bash
     guard reads the command string and fails open, so a wrapper script passes silently).

9. **Wire up verification.** Install `verify/` and tell the user how to run it. Note it reads
   `$HOME/.claude/projects` by default; if you installed somewhere else, set `CLAUDE_PROJECTS_DIR`
   to match or it will report on the wrong sessions. This is how they
   confirm the routing took effect, and the failure it catches is silent — an unpinned delegate
   runs the expensive model and nothing warns them. Do not claim the routing works until a run of
   `verify/check-routing.sh` shows the models they expect.

10. **Report with the canonical installation receipt.** Populate actual values; do not paste
    example states as if observed. Show one compact table and two short lines:

    ```markdown
    ### Prompt Relay installed

    | Role | Model / effort | Setup | Runtime proof |
    |---|---|---|---|
    | Lead | <current or new default> | <unchanged/configured> | <current/new session> |
    | Coder · low | <route> | <installed/not installed> | <proof state> |
    | Coder · high | <route> | <installed/not installed> | <proof state> |
    | Advisor | <route> | <installed/not installed> | <proof state> |
    | QA | <route> | <installed/not installed> | <proof state> |
    | Runner | <route> | <installed/not installed> | <proof state> |

    **Installed:** <actual files/components created, appended, or enabled>
    **Activation:** <host-specific restart or activation instruction, including whether it is required or recommended>
    ```

    Allowed runtime-proof states are `live-verified`, `not invoked`, `mismatch`, `invoked; proof
    unavailable`, and `failed`. `Configured` means the file or setting exists. `Live-verified`
    means a runtime receipt proved the requested model and effort. Parsing one file or canarying one
    role does not verify every role. List every path created or appended, echo the filled roster,
    state the installed tier (single-agent core, core plus agents, or core plus enforcement), and
    never claim a skipped step worked. Label the advisor `manual` only when the installed policy
    actually makes it manual.

# Install — for a human

## Codex

1. Merge the `[agents]` block from `profiles/codex-AGENTS.md` into `~/.codex/config.toml`.
2. Append its `## Model routing & delegation` section to `~/.codex/AGENTS.md` without replacing
   existing rules.
3. Copy `profiles/codex-agents/*.toml` into `~/.codex/agents/` and edit only the model/effort pins
   for your roster.
4. Write the matching `.prompt-relay-roster`, run one harmless canary per pair, then run
   `bash verify/check-routing-codex.sh --since 1 --roster ~/.prompt-relay-roster`.
5. Treat the install as unverified until the transcript shows the intended model and effort.
6. Start a new Codex task so the updated lead default, instructions, and custom-agent registry load
   together; finish the old task with the canonical installation receipt above.

## Claude Code

1. Copy the routing section from `profiles/claude-CLAUDE.md` into your `~/.claude/CLAUDE.md` (or a
   project `.claude/CLAUDE.md`).
2. Edit the Roster block — your models next to each role. Everything else references the role.
3. Copy `references/routing.md` to `~/.claude/references/routing.md`.
4. (Optional) Copy `agents/advisor.md`, `agents/coder-low.md`, `agents/coder-high.md`, and
   `agents/qa.md` into `~/.claude/agents/` and set each `model:`. If any executor
   isn't a Claude model, use `agents/coder-forwarder.example.md` for that role instead.
5. (Optional) Merge `settings.example.json` into your `settings.json` to pin the lead model.
6. (Optional, Claude Code only) For enforcement rather than just advisory rules — because
   `CLAUDE.md` is read, not enforced — copy `hooks/claude/` to `~/.claude/hooks/prompt-relay/`
   and `bin/bulk-read` to `~/.claude/bin/bulk-read`, `chmod +x` both, then merge the `env` and
   `hooks` blocks from `settings.example.json` in. See `hooks/claude/README.md`.
7. Run `verify/check-routing.sh` after your next few delegations and check the models match your
   roster.
8. [Claude Code normally watches existing user/project agent directories](https://code.claude.com/docs/en/sub-agents)
   and applies edits on the next delegation. Restart when the agents directory did not exist at
   session start, when it came from `--add-dir`, or when the session disabled slash commands;
   otherwise a fresh session is a recommended clean activation boundary, not a universal
   requirement. Record which case applies.

# Customising

- **Swap models:** edit the Roster block and the `model:` line in each agent file. Nothing else
  names a model.
- **Add a role:** give it a row in the route table and optionally an `agents/<role>.md`.
- **Trim:** the core loads every turn, so keep it lean — push detail into `references/routing.md`.
- **Check your edits still work:** `evals/` has 20 routing cases and 5 install scenarios. If your
  agent starts routing badly after a change, run the routing eval before guessing.
