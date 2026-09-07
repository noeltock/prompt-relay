# Claude Code hooks

`profiles/claude-CLAUDE.md` and `references/routing.md` are advisory: the lead reads them, and can
skip a rule under pressure the same way it skips anything else in a long transcript. Hooks are
enforced by the harness itself, not read by the model, so they catch the two failures markdown
alone cannot: a large file landing in the lead's context regardless, and a scout agent silently
inheriting the lead's (expensive) model.

## What each hook does

### `read-scope-guard.sh`
**Matcher:** `PreToolUse` / `Read`.
**Blocks:** an unscoped `Read` (no `offset`/`limit`) on a text file over the line threshold.
**Failure it prevents:** the lead's transcript is re-sent as cache on every later turn of the
session, so a single large inline read doesn't cost once — it costs once per remaining turn. A
600-line file read at turn 3 of a 40-turn session is paid for roughly 37 times.
**Passes through:** subagent calls (`agent_id` present — a subagent's context is discarded on
return, so the cost is genuinely one-time there), scoped reads (`offset` or `limit` set), binary
and media formats (png/jpg/pdf/mp3/etc — line count is meaningless), and anything under the
threshold.
**Env:** `RELAY_MIN_LINES` (default `500`).

### `bash-read-guard.sh`
**Matcher:** `PreToolUse` / `Bash`.
**Blocks:** a bare `cat`, `head`, `tail`, `less`, `more`, or `bat` on a file over the same
threshold, with no pipe, redirect, or explicit count.
**Failure it prevents:** `Read` is not the only door to the same problem — `cat big-file.log`
dumps the same content into the same transcript, and `read-scope-guard.sh` alone would miss it
entirely.
**Passes through:** any command containing a pipe or redirection (`cat big | grep x`, `cat big >
out.txt`), `head -n N` / `tail -n N` / `head -N` with an explicit count, compound commands
(`&&`, `;`, `$(...)`, backticks), multiple file arguments, subagent calls, and anything it can't
confidently parse as "one guarded command, one file argument" — see Limits below.
**Env:** `RELAY_MIN_LINES` (shared with `read-scope-guard.sh`).

### `scout-model-pin.sh`
**Matcher:** `PreToolUse` / `Task`.
**Rewrites, never blocks:** if `subagent_type` is the built-in `Explore` or `general-purpose` and
no `model` was passed, it injects one via `updatedInput`.
**Failure it prevents:** `Explore` and `general-purpose` have no `agents/*.md` file, so there's no
frontmatter to default their model on — unpinned, they inherit whatever model is driving the
session. On an expensive lead, every "quick scout" silently runs at flagship rates.
**Passes through:** any other `subagent_type`, and any call that already names a `model` — an
explicit lead choice is never overridden.
**Env:** `RELAY_SCOUT_MODEL` (default `sonnet`).

## `settings.json` wiring

```json
{
  "model": "opus",
  "env": {
    "RELAY_MIN_LINES": "500",
    "RELAY_SCOUT_MODEL": "sonnet",
    "RELAY_BULK_MODEL": "haiku"
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read",
        "hooks": [{ "type": "command", "command": "~/.claude/hooks/prompt-relay/read-scope-guard.sh" }]
      },
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "~/.claude/hooks/prompt-relay/bash-read-guard.sh" }]
      },
      {
        "matcher": "Task",
        "hooks": [{ "type": "command", "command": "~/.claude/hooks/prompt-relay/scout-model-pin.sh" }]
      }
    ]
  }
}
```

See `settings.example.json` in the repo root for the full file this snippet lives in, and
`docs/install.md` for the copy step.

## Limits

- **Claude Code only.** These are Claude Code `PreToolUse` hooks; the Codex profile
  (`profiles/codex-AGENTS.md`) has no equivalent mechanism and is entirely unaffected.
- **`bash-read-guard.sh` reads the command string, not what it does.** It fails open on anything
  ambiguous, which means a wrapper script that `cat`s a large file internally (`./deploy.sh` that
  runs `cat big.log` three levels down) passes through silently. This is the same limit the root
  `CLAUDE.md`'s hook backstop calls out generally: the Bash-matching hooks are a backstop, not a
  guarantee.
- **`scout-model-pin.sh` only sees agents the model spawns by tool call.** A subagent launched by a
  slash command or a skill (including any skill with `context: fork`) never emits a `Task`
  `PreToolUse` event, so the hook never runs and the agent inherits the lead's model. Measured over
  one week on a Fable/Opus lead: 174 of 175 tool-spawned `general-purpose` agents were pinned
  correctly, against 1 of 8 slash-command-launched ones. Pin those in the skill's own frontmatter
  instead; a hook cannot reach that spawn path.
- **`bin/bulk-read` answers lack reliable line numbers.** They're good enough to decide *whether*
  to read further and *where*, not to edit from directly — an edit still needs a direct scoped
  `Read` of the section the answer points to.
- **Below the threshold, delegation costs more than it saves.** A 200-line file read inline is
  cheaper than a `bulk-read` round trip or a scout spawn; the guards exist for the large-file case,
  not to push every read through an extra hop.
