# The learning-loop hook — starter

Doctrine in `CLAUDE.md`/`references/routing.md` lives in prose, and prose competes with recency
every turn — a correction stated once gets buried by whatever the transcript said five minutes
ago, so the same mistake recurs. This is the one guaranteed-delivery channel in the kit: a finding
that has actually recurred gets promoted to `learned/known-failures.md`, and a hook prints it
before the moment it matters, instead of trusting the model to retrieve it from memory.

This is a starter, not a product: one script, one file, zero dependencies beyond `jq`.

## Wire it up (Claude Code)
Add a `PreToolUse` hook to `settings.json` matching the Bash tool (merge, don't clobber — see
`settings.example.json` at the repo root for the combined fragment covering both this hook AND
`logger/log-delegation.sh`; pasting the two READMEs' `"hooks"` blocks separately would clobber one
with the other):
```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [ { "type": "command",
        "command": "/ABSOLUTE/PATH/prompt-relay/hooks/pre-commit-checklist.sh" } ] }
    ]
  }
}
```
The hook only acts when the command contains `git commit`; every other Bash call passes through
untouched. It surfaces the checklist via `hookSpecificOutput.additionalContext` (the PreToolUse
form that actually reaches the model — plain stdout only reaches the user's transcript view) and
only fires once `learned/known-failures.md` has a real `- ` entry under "## Your checklist", not
merely a non-empty file (the file ships with boilerplate even with zero findings promoted).

## How a finding gets in
1. The routing log (`logger/`) records an `outcome: fail` row per delegation.
2. When the same `task_class` fails twice, add one line to `learned/known-failures.md` describing
   the check in plain language — not the bug, the check that would have caught it.
3. From then on, that line prints before every commit. It stops being something the model has to
   remember and becomes something it's shown.

## Advisory by default, a real gate on request
As shipped the hook only prints — it never blocks. Once a specific checklist line has proven
itself (the same class of fail stops recurring after it's been printed a few times, or you want it
enforced rather than just surfaced), turn that one line into a real gate: grep the diff for the
pattern in the hook script and exit `2` instead of `0` when it matches. Exit `2` on a `PreToolUse`
hook blocks the tool call and feeds stderr back to the model as its next instruction. Promote
checklist lines to gates one at a time, only once they've earned it — a hook that blocks on
day one with no evidence just trains the model to route around it.
