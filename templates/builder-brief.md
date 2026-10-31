# Decision-test slice brief. Slice: {{SLICE}} (decisions {{FIRST}} to {{LAST}})

You are the BUILDER. A different session will certify your work and a third, independent agent will re-run it, so write tests that survive a hostile reader.

## Read first
- `{{DECISION_LOG}}`: the decisions in this slice. This is the ONLY source of what each decision means. Quote it; invent nothing.
- Existing tests under `tests/pgtap/` to copy the style from (pgTAP), and any existing mutants under `tests/mutants/`.
- `scripts/run_decision_tests.sh`: the strict runner you must satisfy.

## The database (throwaway only)
- Container for this copy: `{{CONTAINER}}` (set in `decision-lock.env`). Start it with `scripts/db.sh start`; build a fresh database from zero with `scripts/db.sh fresh`.
- In Git Bash always `export MSYS_NO_PATHCONV=1` first, or the `/work` mount breaks.
- NEVER a live or production database. No network. If Docker is not running, STOP and report the exact error; do not try another database.
- Do not edit the production schema code (`db/`). If a test shows the database breaks a decision, record it under "DB defects found" in your report and leave the code alone.
- Do not commit, push or merge.

## What to build for each decision in {{FIRST}} to {{LAST}}
1. Classify it, quoting the log line that justifies it:
   - DB-BUILT: the database should already do this.
   - DB-NOT-BUILT: a database decision with no code yet.
   - NOT-DB: process or workflow, no database behavior.
2. DB-BUILT: write `tests/pgtap/decisions/d_NNN_<slug>.sql` asserting the decided behavior against the fresh DB. Name every assertion `DNNN-xx ...` so a failure names the decision. Then write at least one mutant `tests/mutants/decisions/d_NNN_<what_it_breaks>.sql`: SQL that, applied to a fresh DB, breaks exactly that behavior. Prove the test FAILS with the mutant and PASSES without it.
3. DB-NOT-BUILT: the file's first line is `-- DB-NOT-BUILT`; the test must FAIL with `DNNN: not built yet` (no skip, no todo). It needs no mutant.
4. NOT-DB: no fake test. Record it as not a database decision, with the quote.

## Write GENERAL rules, not one-off cases (required)
For each decision assert the whole class, not the two examples you thought of. Loop over every column, every child table (found from the catalog: `pg_constraint`, `pg_trigger`, `pg_proc`, `pg_class`; never a hard-coded list), every non-system schema, every read path or branch, and every object kind (tables, foreign tables, views, columns, functions). Test every half of each decision (both sides of every "and", every case the log names).
Before handing off, write your own mutants for the edge cases a hostile checker would try (one column only, one branch only, a new object added later).

## Rules the runner enforces
- A mutant counts as killed ONLY when a named pgTAP assertion fails (`not ok`). A setup crash (seal, fixture, constraint error) is CRASHED, not killed, and fails the run.
- Every mutant must be killed: 0 survived, 0 crashed.
- Only create or change files for decisions in THIS slice. Do not touch other slices' tests or mutants. If you must change a shared script, keep it backward compatible and list it in the report.

## Done when
- Every decision in {{FIRST}} to {{LAST}} has a classification with a quote.
- Every DB-BUILT decision has a test that passes on the fresh DB and at least one mutant it kills (output shown).
- Every DB-NOT-BUILT decision fails visibly with "not built yet".
- Running the slice is one command, and you print it: `scripts/run_decision_tests.sh {{FIRST}} ...` (list the numbers).
- You wrote `handoff/slices/{{SLICE}}.md` from `handoff/templates/slice-report.md`: classification table, test and mutant files, pass/fail output, mutants killed and survived, DB defects found, and anything you could not do and why.
Stop after this slice. Do not start the next range.
