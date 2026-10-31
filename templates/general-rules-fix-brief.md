GENERAL RULES FIX for slice {{SLICE}}.

Read `handoff/jobs/SLICE-{{SLICE}}.md` in full first (the original slice brief). Then read the latest certifier report `handoff/slices/{{SLICE}}-cert.md`, every earlier `handoff/slices/{{SLICE}}-cert-*.md`, and the certifier mutants in `handoff/slices/cert-mutants/`.

Why this job exists: several certifier rounds each found a new edge case, and each fix patched only those exact surviving mutants, so the loop never ended. Replace one-off patches with GENERAL rules that cover the whole class of each decision, so a new certifier mutant of the same kind is caught without new code.

Write general assertions per decision. Examples of the shape (adapt to the real schema; read `db/` first):
- "frozen after state X": for the sealed row, loop over EVERY column of the table and EVERY child table that references it (find them from `pg_constraint` and `pg_trigger`, never a hard-coded list): every update, insert and delete must be refused.
- "readers must be scoped": EVERY function in the schema that a given role can execute (from `pg_proc` and `has_function_privilege`) must take the scoping id and must not return another scope's rows on any branch. A lookup with no scoping argument must fail a named assertion.
- "this thing was cut": scan EVERY non-system schema for tables, foreign tables, views, columns AND functions with the cut names; none may exist anywhere.
- "every value of any length": include long, empty, padded and wrong-case inputs, not just the one the log shows.

Rules: do not weaken any assertion, do not delete any mutant, keep every existing named assertion passing (you may fold it into a general one only if the old assertion name still exists and still fails for its mutants). Do not touch the production schema code (`db/`), `decision-lock.env`, the live database, or files outside this slice. Fresh throwaway database only: `export MSYS_NO_PATHCONV=1`, container `{{CONTAINER}}`. No network, no commits.

Prove it: run `scripts/run_decision_tests.sh` for this slice's decisions and show every builder mutant killed by a named assertion, 0 survived, 0 crashed. ALSO apply every certifier mutant in `handoff/slices/cert-mutants/` for this range, one at a time on a fresh database, and show each is killed by a named assertion. If the database code itself breaks a decision, do not change it; record it under "DB defects found".

Update `handoff/slices/{{SLICE}}.md` with a "General rules" section: each general rule per decision, the assertion names, and the new counts. Print the same.
