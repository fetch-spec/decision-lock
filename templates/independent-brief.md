INDEPENDENT RUN of slice {{SLICE}} decision tests. You are an independent agent from a different vendor than the builder and certifier.
Do NOT edit, fix or add any test, mutant, script, schema file or config. No commits, no network, never a live database. Only run and report.

Read `handoff/slices/{{SLICE}}.md` and the latest `handoff/slices/{{SLICE}}-cert*.md` for context.
Database: throwaway Docker only, via this folder's scripts (container `{{CONTAINER}}`, named in `decision-lock.env`). In Git Bash `export MSYS_NO_PATHCONV=1`. Run `scripts/db.sh start`, then use a fresh database (`scripts/db.sh fresh`) before each run.

Run, yourself, on a fresh database each time:
1. `scripts/run_decision_tests.sh` for every decision number in {{FIRST}} to {{LAST}} that has a pgTAP file in `tests/pgtap/decisions/`.
2. Every certifier mutant for this slice in `handoff/slices/cert-mutants/` (files whose number is in the range): fresh database, apply it, run the matching `d_NNN` pgTAP file, record killed (a named assertion fails) / survived / crashed in setup.

Write `handoff/slices/{{SLICE}}-independent-run.md` from `handoff/templates/independent-report.md`: per pgTAP file pass/fail and assertion counts, every mutant killed / survived / crashed, any disagreement with the cert report, and the verdict.

VERDICT RULE: REPRODUCED only if every pgTAP file passes (a DB-NOT-BUILT file counts as passing only when it fails with "DNNN: not built yet") AND every mutant is killed by a failing assertion (0 survived, 0 crashed). Anything else is NOT REPRODUCED. Print the verdict and counts at the end.

VERDICT FORMAT (required): line 3 of your report must be exactly one line starting with `**Verdict:` followed by `REPRODUCED` or `NOT REPRODUCED`. The pipeline reads only the first `**Verdict:` line. Do not start any other line with `**Verdict:`.
