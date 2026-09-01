# Routing eval — 20 cases

Does the doctrine actually decide, or does it just sound decisive? Each case names a task; the
key names the role it should route to. A case you disagree with is worth more than one you pass:
either the doctrine is ambiguous and needs a line, or your stack genuinely differs and your
roster should say so.

**How to run:** see `README.md` in this folder. Grade only the role — the reasoning is for you.

| # | Task | Expected | Why |
|---|---|---|---|
| 1 | "Rename `getUser` to `fetchUser` across the 6 files listed below." | `coder-low` | fully specified, named files |
| 2 | "Rename `getUser` to `fetchUser` everywhere it's used." | `coder-high` | requires wide search before the edit can start |
| 3 | "Add a `deleted_at` column to the schema and the two migrations, following the pattern in `20260102_add_archived.sql`." | `coder-low` | pattern named, decisions made |
| 4 | "Our checkout is slow. Make it faster." | `lead` | choosing the approach IS the work |
| 5 | "Port these 40 test files from Jest to Vitest. The config is already done." | `coder-high` | specified, but size predicts quality more than spec does |
| 6 | "Fix the failing test in `auth.test.ts` — the error is on line 40." | `coder-high` | one file, but the fix still needs judgment |
| 7 | "Something's wrong with session handling, tests pass but users get logged out." | `lead` | symptom only; finding the cause IS the work |
| 8 | "Should we move off Postgres to DynamoDB for this?" | ASK | stack decision, irreversible |
| 9 | "Design the permissions model for multi-tenant orgs." | `lead` | architecture |
| 10 | "Change the button label from 'Send' to 'Submit' in `Form.tsx`." | inline | ≤2 edits, spawn overhead exceeds the saving |
| 11 | "Run the full test suite, the type check and the linter, and tell me what fails." | `qa` | executing a named matrix |
| 12 | "Take these three screenshots and confirm the modal is centred in each." | `qa` | verification, views its own evidence |
| 13 | "We're about to commit to event sourcing for the audit log. Sanity-check me." | `advisor` | load-bearing decision, second opinion |
| 14 | "Fetch these 8 doc pages so I can read them." | `runner` (transport) | but the pages must be written straight to disk, not summarised through a model |
| 15 | "Find out which of these 5 libraries is still maintained." | `runner` | web work, judgment about sources |
| 16 | "Add rate limiting to the API." | `lead`, then delegate | approach unnamed; scope it first, then hand down |
| 17 | "Implement the plan in `PLAN.md` — it names every file and decision." | `coder-low` | pre-approved plan is the ideal cheap-tier input |
| 18 | "Same plan, but it touches 30 files across 4 packages." | `coder-high` | size again |
| 19 | "Review this auth diff for security holes." | `lead` | security is never delegated down |
| 20 | "The executor came back with `BLOCKER: decision — which date library?`" | `lead` answers, re-spawns same role | a blocker is a question, not a promotion; only product/stack calls go to ASK |

## Cases that are meant to be arguable
5 and 20 are the ones people split on. If your answer differs *consistently*, edit your roster or
your route table rather than overriding case by case — a rule you override every time is a rule
that isn't working.

## Baseline
Run cold on 2026-09-01 against the v2 core, three times, by a mid-tier model that had never seen
this repo: **16/20 → 18/20 → 19/20**. Every miss was a hole in the doctrine rather than a bad
answer, which is what this suite is for.

- Round 1 (16/20) added a debugging split, widened the `runner` row, and produced the "if you
  can't write the spec, you can't delegate it" rule. The keys for cases 6 and 7 were corrected —
  the tester was right and the original key was wrong.
- Round 2 (18/20) failed on the two rows that named two roles with no tiebreaker. Both now name
  one.
- Round 3 (19/20) surfaced that the doctrine never said *who* answers a decision blocker. It does
  now. That last line landed after the run, so it is untested — re-run and you should see 20/20.

If you score well below 16 on a stock install, that points at placement rather than wording:
check the core is actually in the file your harness loads.
