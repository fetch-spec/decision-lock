---
name: decision-lock
description: Use when a written decision log must be locked in with tests, so that every decision (D001, D002, ...) has a database test that fails if the decision is dropped, built in slices of 10 with a builder, a separate certifier and an independent agent that reproduces the result.
---

# decision-lock

A written decision log is the source of truth. Every decision becomes a test named after it, run against a real throwaway database (Docker Postgres + pgTAP), that FAILS if the decision is dropped or ignored. Like traceability in a regulated industry: for every decision you can point at the test that proves it, and at the deliberately broken copy of the code (a mutant) that proves the test can fail.

This skill is the method plus the scripts in `scripts/` and the briefs in `templates/`. You are either the coordinator (setting up and running slices) or one of the roles below (builder, certifier, independent run). A brief file tells a role exactly what to do; follow it.

## Hard rules (apply in every role)

1. **Never run against a live or production database.** Throwaway container only, built from zero. Mutants are destructive by design.
2. **Briefs go to CLIs by file pointer**, never inline: the prompt is `Read the file X in full and do exactly what it says. It is your complete brief.`
3. **A tool error is STOPPED, not a test failure.** No report written, or a nonzero CLI exit: stop and say so. Never loop a tool error to the builder.
4. **A setup crash is not a kill.** A mutant is killed only when a named pgTAP assertion fails (`not ok`) and the file still reaches its plan.
5. **Read a verdict only from the first `**Verdict:` line** of a report (line 3 by convention), never by searching the whole file.
6. **The role that wrote a test never certifies it.** Different sessions; the independent run uses a different vendor.
7. **Tests check the actual database code.** If a test shows the database breaks a decision, record it under "DB defects found"; do not edit production SQL to make a test pass.
8. In Git Bash set `MSYS_NO_PATHCONV=1` before Docker calls with `/work` paths. In PowerShell never name a helper after the exe it runs.

Full stories for each: `docs/LESSONS.md`.

## Setup (coordinator)

1. Requirements: Docker, bash, an agent CLI for the builder/certifier (Claude Code `claude`), and a CLI from another vendor for the independent run (`grok`, `codex`). `scripts/db.sh build` builds the Postgres+pgTAP image.
2. Project layout the scripts expect (copy `scripts/` into the project, or point `DL_ROOT` at it):
   - `decision-log.md` (or any path; give it to `new-slice.sh`): see `templates/decision-log.example.md`.
   - `db/*.sql`: the schema, applied in name order to build a fresh database.
   - `tests/pgtap/decisions/d_NNN_<slug>.sql`, `tests/mutants/decisions/d_NNN_<what>.sql`.
   - `decision-lock.env` (optional): `IMAGE`, `CONTAINER`, `DBNAME`, `SCHEMA_DIR`.
3. Number decisions D001, D002, ... in the log, one decision per entry, plain words. Split compound decisions. Cut the log into slices of 10 (`D001-D010`, `D011-D020`, ...).
4. For each slice: `scripts/new-slice.sh <project> D011-D020 <slice-copy-dir> decision-log.md`. It makes a private copy with its own container name and renders the four briefs into `handoff/jobs/`.
5. Run it: `scripts/pipeline.sh --slice D011-D020 --dir <slice-copy-dir>` (or `scripts/pipeline.ps1 -Slice D011-D020 -Dir <slice-copy-dir>` on Windows). Start slices in parallel, each in its own copy. Watch them every 30 minutes (`docs/WATCHER.md`).

## The flow per slice

1. **BUILDER** (`handoff/jobs/SLICE-<slice>.md`). Classify each decision, quoting the log:
   - DB-BUILT: the database should already do it. Write `d_NNN_*.sql` (assertions named `DNNN-xx ...`) and at least one mutant that breaks exactly that behavior; show the test fails with the mutant and passes without.
   - DB-NOT-BUILT: first line `-- DB-NOT-BUILT`; the test must fail with `DNNN: not built yet`. No skip, no todo.
   - NOT-DB: process or workflow. No fake test; record it with the quote.
   Write **general rules**, not examples (below). Write the slice report `handoff/slices/<slice>.md`.
2. **CERTIFIER** (`...-CERT.md`, a separate session). Re-run everything on a fresh database; check each classification against the log; check each test asserts the decision and not something weaker; re-run old certifier mutants first, then write at most 5 new ones; rate each problem HIGH / MEDIUM / LOW. Only MEDIUM+ blocks. Writes `<slice>-cert.md` with `**Verdict: CERTIFIED` or `**Verdict: NOT CERTIFIED` on line 3. Fixes nothing.
3. **Loop back** on NOT CERTIFIED: the pipeline renders `templates/cert-fix-brief.md` with the cert report as input and runs the builder again, then a fresh certifier. Maximum 3 loops.
4. **INDEPENDENT** (`...-INDEPENDENT.md`, an agent from a different vendor; run-only, edits nothing). REPRODUCED only if every test file passes and every mutant is killed by a named failing assertion (0 survived, 0 crashed). Anything else is NOT REPRODUCED.
5. **Loop back** on NOT REPRODUCED through `templates/independent-fix-brief.md` (builder finds the root cause and fixes it), then a new independent run. Maximum 3 loops.
6. **Human last.** Only after the loops are exhausted does a person hear about a slice, with the root cause already found. Never report a single failed run.

Pipeline exit codes: 0 REPRODUCED, 3 STOPPED (tool error), 4 still NOT CERTIFIED, 5 still NOT REPRODUCED.

## Writing tests that survive a certifier

Why: a fresh certifier every round finds a new edge case forever (one slice took nine rounds when fixes only patched the exact case found). So:

- **Builders write GENERAL rules.** Loop over every column; find child tables from the catalog (`pg_constraint`, `pg_trigger`), functions from `pg_proc` (+ `has_function_privilege`), objects from `pg_class`; scan every non-system schema; cover every read path or branch; cover every object kind (tables, foreign tables, views, columns, functions). Never a hard-coded list of names that a new column or table would escape. Test both halves of every "and" in the decision. Include odd inputs: long, empty, padded, wrong case.
- **Certifiers re-check old mutants first, then add at most 5.** LOW problems never block.
- If a general-rules pass is needed, use `templates/general-rules-fix-brief.md` (`--fix-first`).
- A mutant is SQL that is applied to a fresh database and breaks one behavior (drop a constraint, replace a function body, add a bypass function, grant a privilege). It must be killed by an assertion that names the decision.

## Test file conventions

- `BEGIN; SELECT plan(n); ... SELECT * FROM finish(); ROLLBACK;` with the plan computed from the catalog when assertions are generated by a query.
- Assertion names start with `DNNN-xx`; the runner prints which names failed for each killed mutant.
- pgTAP lives in schema `tap`; the runner sets `search_path=public,tap`, so the files call `plan()` unqualified.
- Use `throws_ok(sql, sqlstate, message, name)` with the real SQLSTATE or message so a different error does not count as a catch.

## Running

```
scripts/db.sh start                         # throwaway container
scripts/run_decision_tests.sh               # every decision; or: ... 011 012
scripts/db.sh stop
```

Output per decision: `PASS clean`, one `killed <mutant> [assertions]` line per mutant, or `SURVIVED` / `CRASHED` / `MUTANT DID NOT APPLY` / `NOT BUILT`. The exit code is the number of problems; DB-NOT-BUILT decisions count, so the gap stays visible.

A worked example with three decisions, general-rule tests, nine mutants and sample reports is in `examples/orders/`.

## Reports (what to write)

- Builder: `templates/slice-report.md` -> `handoff/slices/<slice>.md`.
- Certifier: `templates/cert-report.md` -> `handoff/slices/<slice>-cert.md` (verdict on line 3).
- Independent: `templates/independent-report.md` -> `handoff/slices/<slice>-independent-run.md` (verdict on line 3).

## Parallel slices

One working copy and one container per slice (`new-slice.sh`). Afterwards merge the slice's new files back into the main project, excluding `decision-lock.env`.
