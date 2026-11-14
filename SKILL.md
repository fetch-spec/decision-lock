---
name: decision-lock
description: Use when decisions in a written decision log must each be locked in with a test that fails if the decision is dropped, proven by mutants (deliberately broken copies the test must catch), built in slices of 10 by a builder, a separate certifier and an independent agent. Engines - pgtap (Postgres in Docker, with the project-skill generator create-decision-lock) or tap (any framework that prints TAP, runner only).
license: MIT
---

# decision-lock

A written decision log is the source of truth. Every decision becomes a test named after it, run against a real throwaway database (Docker Postgres + pgTAP), that FAILS if the decision is dropped or ignored. Like traceability in a regulated industry: for every decision you can point at the test that proves it, and at the deliberately broken copy of the code (a mutant) that proves the test can fail.

This skill is the method plus the scripts in `scripts/` and the briefs in `templates/`. You are either the coordinator (setting up and running slices) or one of the roles below (builder, certifier, independent run). A brief file tells a role exactly what to do; follow it.

## Scope and when to use it

- **Two engines** (`DL_ENGINE`, see the header of `scripts/run_decision_tests.sh`). `pgtap` (default): Postgres + pgTAP in a throwaway Docker container, plus the `create-decision-lock` generator and the per-slice pipeline scripts. `tap`: any framework that prints TAP (bats, pytest-tap, `node --test`, `prove`), no Docker; set `DL_FRESH_CMD`, `DL_RUN_CMD`, `DL_MUTANT_CMD`. Try it: `DL_ROOT=examples/tap-demo scripts/run_decision_tests.sh`.
- **The `tap` engine is the strict runner only.** The generator (`create-lock.sh`), the generated `lock.sh` and the slice briefs are still pgTAP/Docker. For a non-Postgres project you get the same kill rules (killed only by a named failing assertion; a crash or a missing plan is not a kill) but you drive the builder/certifier/independent roles yourself.
- Decisions that are not testable behaviour (process, UI) are recorded as NOT-DB with a quote and get no test.
- **Costly: use it where a dropped decision hurts** (roles, RLS, immutability, audit, money). A full slice runs a builder, a certifier and an independent agent, with up to 3 fix loops each. A slice can still end NOT CERTIFIED; that is the check working.
- **Not for every decision.** For low-stakes rules, write one pgTAP test by hand.


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


## Pipeline detail

The per-slice flow (builder, certifier, independent, fix loops, exit codes), the rules for writing tests that survive a certifier, test file conventions, the run output format, report templates and parallel slices are in [`docs/PIPELINE.md`](docs/PIPELINE.md). Read it before running a slice.
