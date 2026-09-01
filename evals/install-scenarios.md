# Install eval — 4 scenarios

The install path is agent-run, so it needs testing the way an agent will hit it: cold, with only
the repo to go on. Run each scenario against a fresh agent session with no memory of this repo.

For each: paste the scenario prompt, let the agent work, then grade against the criteria. A
failure here is a documentation bug, not a user error.

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
- [ ] States that fan-out is on by default here and this is spend control, not a saving
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
## Results
Run 2026-09-01: all four scenarios pass, on a fresh agent with only the repo to go on.

Run them again after you change your roster or the install steps. They earn their keep by
failing: every defect they found was in the docs, not in the tester's answers.
