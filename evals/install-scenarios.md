# Install eval — 5 scenarios

The install path is agent-run, so it needs testing the way an agent will hit it: cold, with only
the repo to go on. Run each scenario against a fresh agent session with no memory of this repo.

For each: paste the scenario prompt, let the agent work, then grade against the criteria. A
failure here is a documentation bug, not a user error.

For every successful installation scenario (S1, S2, S3, and S5), also require the shared receipt:

- [ ] Ends with one compact role/model/setup/runtime-proof table
- [ ] Lists the actual installed components or paths
- [ ] Distinguishes configured, not invoked, and live-verified states
- [ ] Never treats one successful canary as proof that every role works
- [ ] Gives a bold, accurate host-specific activation instruction: a fresh Codex task as the clean
      boundary; Claude restart only when its watched-directory rules require it, otherwise recommended
- [ ] Uses one-line runtime dispatch/completion signals rather than multiline cards

---
## S1 — Claude only
> "I have a Claude Max subscription and nothing else. Install prompt-relay."

**Pass criteria**
- [ ] Asks about subscriptions/access before proposing models
- [ ] Proposes a roster and waits for confirmation before writing
- [ ] Does NOT assign a coding role to the cheapest/smallest model
- [ ] Backs up an existing `CLAUDE.md` rather than overwriting it
- [ ] Appends the routing core under a marked block, leaving existing rules intact
- [ ] Does not install the cross-vendor forwarder (not needed here)

---
## S2 — Codex only
> "I use Codex, no Claude subscription. Install prompt-relay."

**Pass criteria**
- [ ] Routes to the Codex profile and does NOT write anything into `~/.claude/`
- [ ] Names the pin for the default subagent model as non-optional
- [ ] Installs or proposes the Codex custom-agent TOMLs separately from the portable policy
- [ ] Requires a live canary plus transcript verification for each model/effort pair
- [ ] States that subagent work adds tokens and does not promise a saving
- [ ] Does not copy the Claude cost claims across

---
## S3 — Both vendors
> "Claude Max plus a ChatGPT plan with Codex. I want the cheap stuff running on Codex."

**Pass criteria**
- [ ] Uses the forwarder pattern for the non-Claude executors — does NOT write a foreign
      model name into a sub-agent's `model:` field
- [ ] States the external CLI dependency before installing anything that needs it
- [ ] Roster keeps decisions and review on the lead
- [ ] Tells the user how to confirm the pins took effect

---
## S4 — The accidental adopter
> Open a fresh agent session with the working directory set to a clone of this repo, and ask it
> to "summarise the coding conventions for this project".

**Pass criteria**
- [ ] The agent does NOT adopt the routing rules as instructions for editing this repo
- [ ] It recognises the repo as a template whose contents are inert until installed

*(S4 is a regression test. It failed before v2, when the routing core sat at the repo root under
a filename every Claude Code session auto-loads.)*

---
## S5 — Enforcement opt-in (Claude Code)
> Fresh agent, `~/.claude` present. Paste the README install prompt and, when asked, say you want
> the hooks as well.

**Pass criteria**
- [ ] Offers enforcement as optional, after the routing core, not as a default
- [ ] Copies `hooks/claude/` and `bin/bulk-read` to the paths `docs/install.md` names and marks them executable
- [ ] Merges the `env` and `hooks` blocks from `settings.example.json` without clobbering existing hooks
- [ ] States that these hooks are Claude Code only and leave a Codex install unchanged
- [ ] Runs `evals/run-hook-evals.sh` and reports the result

---
## Results
Run 2026-09-01: S1–S4 pass, on a fresh agent with only the repo to go on. S5 added 2026-09-06, not yet run.

Run them again after you change your roster or the install steps. They earn their keep by
failing: every defect they found was in the docs, not in the tester's answers.
