---
name: decision-lock
description: Use when a written decision log must be locked in with tests (or to generate a project-specific lock skill with create-decision-lock), so that every decision (D001, D002, ...) has a database test that fails if the decision is dropped, built in slices of 10 with a builder, a separate certifier and an independent agent that reproduces the result.
license: MIT
---

# decision-lock

A written decision log is the source of truth. Every decision becomes a test named after it, run against a real throwaway database (Docker Postgres + pgTAP), that FAILS if the decision is dropped or ignored. Like traceability in a regulated industry: for every decision you can point at the test that proves it, and at the deliberately broken copy of the code (a mutant) that proves the test can fail.

This skill is the method plus the scripts in `scripts/` and the briefs in `templates/`. You are either the coordinator (setting up and running slices) or one of the roles below (builder, certifier, independent run). A brief file tells a role exactly what to do; follow it.

## Hard rules (apply in every role)

0. **A check you have never seen fail proves nothing.** Prove it can fail (break on purpose, restore byte for byte, show it passes again) before trusting it.
1. **Never run against a live or production database.** Throwaway container only, built from zero. Mutants are destructive by design.
2. **Briefs go to CLIs by file pointer**, never inline: the prompt is `Read the file X in full and do exactly what it says. It is your complete brief.`
3. **A tool error is STOPPED, not a test failure.** No report written, or a nonzero CLI exit: stop and say so. Never loop a tool error to the builder.
4. **A setup crash is not a kill.** A mutant is killed only when a named pgTAP assertion fails (`not ok`) and the file still reaches its plan.
5. **Read a verdict only from the first `**Verdict:` line** of a report (line 3 by convention), never by searching the whole file.
6. **The role that wrote a test never certifies it.** Different sessions; the independent run uses a different agent (a different vendor is recommended).
7. **Tests check the actual database code.** If a test shows the database breaks a decision, record it under "DB defects found"; do not edit production SQL to make a test pass.
8. In Git Bash set `MSYS_NO_PATHCONV=1` before Docker calls with `/work` paths. In PowerShell never name a helper after the exe it runs.

Full stories for each: `docs/LESSONS.md`.

## create-decision-lock (the generator)

One generic skill, saved once. Invoked in any project by a plain instruction ("run the create-decision-lock skill", i.e. follow this SKILL.md; no slash command or vendor feature is needed), it WRITES a project-specific verification skill into that project at `.agents/skills/lock-<project>/` (a neutral path; any tool-specific skills folder can symlink or copy it). There is no one-size-fits-all check: the generator builds the bespoke one. Everything below (decision log, builder, separate certifier, independent rerun, fix loops, severity rule, named-assertion kills, strict harness) stays and is what the generated skill runs.

**A check you have never seen fail proves nothing.** The generator never hands over a skill that has not failed on purpose once.

Steps, in order. Do not skip or reorder:

1. **Discovery: the five questions** (`templates/five-questions.md`, with a worked example). Read the project, answer all five, show the answers, write nothing yet:
   - **Decisions**: where is the decision log, how are decisions numbered (D001...)?
   - **Run**: how is a throwaway copy of the system started (container, temp DB, temp dir)?
   - **Drive**: which test frameworks assert each decision (pgTAP, pytest, jest)?
   - **Observe**: what evidence is kept (per-decision report, kill matrix, receipts, verdict line)?
   - **Isolate**: can slices run in parallel, each with its own copy and container/port?
2. **Tool proposal and approval gate** (`templates/tool-proposal.md`). List each tool: what it does, why this project needs it. Then STOP and wait for the human to say go. If they ask, explain a tool or offer an alternative. Nothing is written before the go.
3. **Generate** after go: `scripts/create-lock.sh <project-dir> <name> --approved [decision-log]` (refuses without `--approved`). It writes only `.agents/skills/lock-<name>/` from `templates/project-skill/`:
   - `SKILL.md` with `## Launch`, `## Doctor`, `## Drive`, `## Evidence`, `## Cleanup`, `## Helpers`
   - `decisions/D001.md ...`, one file per decision (verbatim text, rule class, tests, mutants, status)
   - `scripts/lock.sh` and `scripts/lock.ps1`: ONE CLI with subcommands `launch`, `doctor`, `run <slice|ids>`, `evidence`, `cleanup` (plus `selftest`), each printing one JSON object (`{"ok":true,...}`). It wraps the unchanged engine in `engine/` (`db.sh`, `env.sh`, `run_decision_tests.sh`).
4. **Self-test before handover** (`lock.sh selftest <id>`). Pick one decision, apply one mutant (break it on purpose), show the run FAILS by a named assertion, restore the file byte for byte (sha256 before and after must match), show the run PASSES. Record it as "Proof it can fail" in the evidence (`handoff/evidence/selftest.json`, copied into `EVIDENCE.md`). If any step fails, the skill is not ready: fix the cause and rerun.
5. **Integration: propose, never silently apply.** End by showing the one line from `templates/agents-md-rule.md` for the project's AGENTS.md (agents that read a different file, for example CLAUDE.md or GEMINI.md, can point that file at AGENTS.md): "Before you call any change that touches a recorded decision done, run the lock-<project> skill for those decisions and show its evidence." Write it only if the human agrees.

**Teach mode** (`templates/teach-example.md`). A human adds a decision by giving ONE example of good data and ONE of bad data (or one real failing case). The builder turns it into a test plus a mutant, generalizes it to the whole rule, and shows it failing and passing with `lock.sh run` and `lock.sh selftest`.

The orders example includes a generated tree: `examples/orders/.agents/skills/lock-example/`, with the recorded break-and-restore proof in `examples/orders/handoff/evidence/`.

## Setup (coordinator)

1. Requirements: Docker, bash, and an agent CLI for each role (builder, certifier, independent runner, fixer), configured in one `decision-lock.agents` file (`templates/decision-lock.agents.example`). The certifier and independent runner must be a different agent/session from the builder; a different vendor is recommended for the independent runner. A human can fill any role. `scripts/db.sh build` builds the Postgres+pgTAP image.
2. Project layout the scripts expect (copy `scripts/` into the project, or point `DL_ROOT` at it):
   - `decision-log.md` (or any path; give it to `new-slice.sh`): see `templates/decision-log.example.md`.
   - `db/*.sql`: the schema, applied in name order to build a fresh database.
   - `tests/pgtap/decisions/d_NNN_<slug>.sql`, `tests/mutants/decisions/d_NNN_<what>.sql`.
   - `decision-lock.env` (optional): `IMAGE`, `CONTAINER`, `DBNAME`, `SCHEMA_DIR`.
3. Number decisions D001, D002, ... in the log, one decision per entry, plain words. Split compound decisions. Cut the log into slices of 10 (`D001-D010`, `D011-D020`, ...).
4. For each slice: `scripts/new-slice.sh <project> D011-D020 <slice-copy-dir> decision-log.md`. It makes a private copy with its own container name and renders the four briefs into `handoff/jobs/`.
5. Copy `templates/decision-lock.agents.example` to `decision-lock.agents` in the slice copy and fill in the command for each role (or set `DL_AGENTS`). Then run it: `scripts/pipeline.sh --slice D011-D020 --dir <slice-copy-dir>` (or `scripts/pipeline.ps1 -Slice D011-D020 -Dir <slice-copy-dir>` on Windows). Start slices in parallel, each in its own copy. Watch them every 30 minutes (`docs/WATCHER.md`).

## The flow per slice

1. **BUILDER** (`handoff/jobs/SLICE-<slice>.md`). Classify each decision, quoting the log:
   - DB-BUILT: the database should already do it. Write `d_NNN_*.sql` (assertions named `DNNN-xx ...`) and at least one mutant that breaks exactly that behavior; show the test fails with the mutant and passes without.
   - DB-NOT-BUILT: first line `-- DB-NOT-BUILT`; the test must fail with `DNNN: not built yet`. No skip, no todo.
   - NOT-DB: process or workflow. No fake test; record it with the quote.
   Write **general rules**, not examples (below). Write the slice report `handoff/slices/<slice>.md`.
2. **CERTIFIER** (`...-CERT.md`, a separate session). Re-run everything on a fresh database; check each classification against the log; check each test asserts the decision and not something weaker; re-run old certifier mutants first, then write at most 5 new ones; rate each problem HIGH / MEDIUM / LOW. Only MEDIUM+ blocks. Writes `<slice>-cert.md` with `**Verdict: CERTIFIED` or `**Verdict: NOT CERTIFIED` on line 3. Fixes nothing.
3. **Loop back** on NOT CERTIFIED: the pipeline renders `templates/cert-fix-brief.md` with the cert report as input and runs the builder again, then a fresh certifier. Maximum 3 loops.
4. **INDEPENDENT** (`...-INDEPENDENT.md`, an agent that is not the builder, ideally from a different vendor; run-only, edits nothing). REPRODUCED only if every test file passes and every mutant is killed by a named failing assertion (0 survived, 0 crashed). Anything else is NOT REPRODUCED.
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
