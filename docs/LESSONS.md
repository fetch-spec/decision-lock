# Lessons

Eleven things that went wrong, or would have, while this method was run on a real decision log with several slices in parallel. Each is written as the failure to expect, so you do not repeat it. Stories 1, 4, 5 and 7 are exact accounts of what happened; in the others the mechanism is real and the details are described in general terms.

## 1. Pass briefs to CLIs by file pointer, never inline

**Rule.** The prompt you give an agent CLI is one short line: `Read the file <path> in full and do exactly what it says. It is your complete brief.` The brief itself lives in a file.

**What happened.** Fix briefs were first passed as multi-line text on the command line. Windows PowerShell 5 cuts a multi-line argument at the first double quote, so the agent received half a brief, did half the work, and reported success. Nobody noticed for a round.

**Why it works.** A file cannot be truncated by a shell, and it stays on disk as a record of exactly what the agent was told.

## 2. A tool error is STOPPED, not a test failure

**Rule.** If the agent CLI exits nonzero, or the report file it should have written does not exist, the pipeline prints `STOPPED` and exits. It never sends that to the builder as a "problem to fix".

**The failure.** A rate limit, a crashed CLI or a closed terminal makes the certifier exit without writing a report. A script that treats "no report" like "failed certification" starts a fix loop: the builder is asked to fix problems nobody found, edits working tests, and can break them.

**Why it works.** Only a judgment (a verdict written by a certifier or an independent run) is evidence about the tests. No judgment means no evidence, so a human or the watcher retries the tool.

## 3. A setup crash is not a kill

**Rule.** A mutant is killed only when a named pgTAP assertion reports `not ok` and the test file still reaches its plan. If the file dies before its plan (a fixture insert fails, a constraint trips during setup, a function the test needs is gone), the mutant is CRASHED. That proves nothing and fails the run exactly like a survivor.

**The failure.** A mutant removes something the test's own fixture needs (a column, a function). The test dies in setup, a runner that only asks "did the test pass?" counts the mutant as caught, and the test is credited with detecting a behavior it never examined. This showed up in the first slice and is why the runner has the CRASHED category.

**Why it works.** "Failing" and "failing on the right thing" are different. Requiring a named `not ok` ties each kill to a specific assertion about the decision.

## 4. Read the verdict from the first `**Verdict:` line only

**Rule.** Reports quote earlier verdicts ("round 2 said NOT CERTIFIED because..."). The pipeline parses the single first line that starts with `**Verdict:`, and the briefs make that line 3 of the report. It never searches the whole file for a word.

**What happened.** A certifier passed the slice, but its report mentioned "the previous round was NOT CERTIFIED" in the body. The script searched the whole file for `NOT CERTIFIED`, read a pass as a fail, and ran three fix loops on a slice that was already fine.

**Why it works.** There is exactly one place a verdict can live. Anything else in the file is prose.

## 5. Moving goalposts: a fresh certifier finds a new edge forever

**Rule.** Builders write GENERAL rules. Certifiers re-run all earlier certifier mutants first, then add at most 5 new ones. Only MEDIUM and HIGH problems block; LOW never does.

**What happened.** One slice took nine certifier rounds. Each fresh certifier tried a slightly different mutant ("what if only one column is checked", "what if a second child table exists", "what if a function without the id argument is added"). Each fix patched exactly that case, so the next certifier found the next one.

**Why it works.** Patching a case never closes a class. The fix was a separate "general rules" brief: tests loop over every column, find child tables and functions from the catalog (`pg_constraint`, `pg_trigger`, `pg_proc`, `pg_class`), scan every non-system schema and every object kind. After that the same slice certified in one round. A severity rule stops the loop from chasing taste: if all that is left is LOW, the answer is CERTIFIED.

## 6. Never report a single failed run; loop it, and find the root cause first

**Rule.** One red run is a lead, not a result. The pipeline loops failures back to the builder (max 3), and a human is told only after the loops are exhausted, with the root cause already found.

**The failure.** If every red run goes straight to the owner, most of what they see is stale state, a leftover container or a tool hiccup.

**Why it works.** Loops are cheap and the builder has the context to find the cause. The owner's attention is for what the loops could not solve.

## 7. Windows details: `MSYS_NO_PATHCONV=1`, and do not name a helper after the exe

**Rule.** In Git Bash set `MSYS_NO_PATHCONV=1` before any `docker` call that has a path like `/work` in it. In PowerShell, name your helper function differently from the program it runs.

**What happened.** Git Bash silently rewrote `/work/tests` into a Windows path, so the container mount was empty and every test "file not found". Separately, a PowerShell function named `Claude` that called `claude` called itself, because PowerShell resolves functions before programs; it recursed until the stack was gone.

**Why it works.** `scripts/env.sh` exports the variable for every script, and the PowerShell helper is called `Invoke-Cli`.

## 8. Parallel slices need separate working copies and containers

**Rule.** Each slice gets its own copy of the project and its own database container (`scripts/new-slice.sh`). Afterwards merge the slice's files back, excluding the per-copy `decision-lock.env`.

**The failure.** Two slices sharing one container: each runner drops and rebuilds "the" database while the other is mid-test, and both see random failures that vanish when rerun alone. A shared working tree has the same problem with half-written files.

**Why it works.** Nothing is shared, so nothing can interfere. The cost is a merge step, which is mechanical.

## 9. Tests check the actual database code; defects are recorded, not fixed

**Rule.** If a test shows the database breaks a decision, the builder writes it under "DB defects found" and does not edit the production SQL. The failing test stays failing until the owner decides.

**The failure.** A builder "makes its test pass" by editing the schema. The test then proves the builder's edit, not the decision, and the real defect is invisible in the report.

**Why it works.** The tests are an audit of the code. An auditor who can change the thing being audited is not auditing.

## 10. Never run against a live or production database

**Rule.** Tests run on a throwaway container built from zero. Mutants are destructive by design (they drop constraints and replace functions). Every brief says so, and `db.sh` refuses to touch a container that does not carry its own label.

**Why.** There is no second chance after a mutant runs on real data. Keep the connection string of any real database out of the working copy entirely.

## 11. A check you have never seen fail proves nothing

**Rule.** Before a check is trusted, break one thing on purpose and watch the check fail by name, put the thing back exactly (compare hashes), and watch the check pass again. The generated lock skill is not handed over until `lock.sh selftest` has done this and recorded it as "Proof it can fail".

**The failure.** A check that has only ever printed green may be checking nothing: wrong directory, empty test list, an assertion that cannot fail, a container that is not the one under test. Everything looks fine until the day it matters.

**Why it works.** One deliberate failure shows the check is wired to the real system and that its failure message points at the right decision. Restoring byte for byte, proven by a hash, shows the experiment left nothing behind, and the final pass shows the check recovers.
