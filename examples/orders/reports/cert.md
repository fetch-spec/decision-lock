# Certification: slice D001-D003 (sample)

**Verdict: CERTIFIED. 0 problems (0 high, 0 medium, 0 low).**

> Illustrative sample. The numbers come from a real run of this example with `scripts/run_decision_tests.sh`; the layout is what a certifier report looks like. Line 3 is the only line the pipeline reads.

## Re-run
`DL_ROOT=examples/orders scripts/run_decision_tests.sh` on a fresh database before every file and every mutant: exit 0.
- 3 test files pass clean (D001: 13 assertions, D002: 15, D003: 9).
- 0 not-built files (no DB-NOT-BUILT decision in this slice).
- Builder mutants: 9 killed, 0 crashed, 0 survived.

## Classification check
| Decision | Class | Agree with the log quote? |
|---|---|---|
| D001 | DB-BUILT | yes: "exactly one of new, paid, shipped, cancelled ... anything else ... is refused" |
| D002 | DB-BUILT | yes: "neither the order nor any of its lines can be changed or deleted, and no line can be added" |
| D003 | DB-BUILT | yes: "only through functions that take their customer id ... no direct table access" |

## Do the tests assert what the decision says?
Yes. D001 tests all four accepted values, five refused values (unknown, upper case, mixed case, padded, empty), null, an update to an unknown value, and the default. D002 reads every column of the order and of every child table from the catalog and checks each update is refused, plus delete on every child table, insert of a line and moving a line; the open order stays editable. D003 reads every function the customer role can run from `pg_proc` and requires `p_customer_id`, and checks both read paths and table privileges.

## Earlier certifier mutants (re-checked first)
None: this is round 1.

## My new mutants (at most 5)
None in this sample (a real certifier writes up to 5 here, saves them as `handoff/slices/cert-mutants/c_NNN_<what>.sql`, and reports each as killed by an assertion name, survived, or crashed).

## Problems
None. (A real report lists each as: number, HIGH / MEDIUM / LOW, decision, problem.)

## Notes (low, non-blocking)
None.
