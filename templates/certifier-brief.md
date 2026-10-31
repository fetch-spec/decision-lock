# Slice certifier. Slice: {{SLICE}}

You are a separate session. You did not write this slice and you must not fix it.
Read `handoff/jobs/SLICE-{{SLICE}}.md` (what the builder was told). The same Don'ts apply: throwaway Docker database only (container `{{CONTAINER}}`), never live, no network, no commits. In Git Bash `export MSYS_NO_PATHCONV=1`.

## Check the builder's work for {{FIRST}} to {{LAST}}
Use `handoff/slices/{{SLICE}}.md`, the decision log (`{{DECISION_LOG}}`) and the files the report lists.
- Is each classification right, per the log quote?
- Does each DB-BUILT test actually assert what the decision says, not something weaker? Both halves of every "and"?
- Re-run every test on a fresh database (must pass) and every builder mutant (must be killed).
- Does each DB-NOT-BUILT decision fail with "not built yet"?
- Moving goalposts rule: FIRST re-run every mutant from earlier certifier rounds in `handoff/slices/cert-mutants/` (if any). A survivor there is at least MEDIUM. THEN write at most 5 new mutants of your own, save them in `handoff/slices/cert-mutants/` named `c_NNN_<what>.sql`, and report whether each was killed.
- Certify by the rule: a mutant is caught only by a failing named assertion; a setup crash is not a catch.

## Severity
Rate every problem HIGH, MEDIUM or LOW.
- HIGH: a decision is not tested, or a test asserts something other than the decision.
- MEDIUM: a plausible mutant of the decision survives, or a test only covers one half or one case of a class.
- LOW: style, naming, an unlikely edge, a report typo.
The verdict is NOT CERTIFIED only if there is at least one MEDIUM or HIGH problem. LOW problems never block: write CERTIFIED and list them under a "Notes (low, non-blocking)" heading.

## Output
Write `handoff/slices/{{SLICE}}-cert.md` from `handoff/templates/cert-report.md`. Do not fix anything.

VERDICT FORMAT (required): line 3 of your report must be exactly one line starting with `**Verdict:` followed by `CERTIFIED` or `NOT CERTIFIED`. The pipeline reads only the first `**Verdict:` line. Do not start any other line with `**Verdict:` and do not quote an earlier verdict at the start of a line. Print the verdict and the problem count.
