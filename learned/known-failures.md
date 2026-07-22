# Known failures — promoted from the routing log

A finding earns a line here once it has actually recurred: the routing log's `outcome: fail`
rows repeat the same `task_class` twice or more. This file is the guaranteed-delivery channel —
`hooks/pre-commit-checklist.sh` prints it before every `git commit`, so a repeat finding reaches
the model deterministically instead of competing with whatever's most recent in the transcript
(prose in `CLAUDE.md` loses that fight; a printed checklist doesn't).

Doctrine in `CLAUDE.md` and `references/routing.md` is the default. This file is the override for
the specific mistakes *your* stack has actually made twice — keep it short, a long checklist stops
getting read.

## Format
One line per confirmed-recurring failure, plainest possible phrasing:
- `<what to check> — <why, one clause>`

## Your checklist
(empty — add a line the second time the same fail outcome repeats in the routing log)
