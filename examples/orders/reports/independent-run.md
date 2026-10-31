# Independent run: D001-D003 (sample)

Independent agent (not the builder; a different vendor is recommended). Run-only: nothing edited, no commits, throwaway container `decision-lock-example` only.

**Verdict: REPRODUCED**

> Illustrative sample. The numbers come from a real run of this example. Line 3 is the only line the pipeline reads. The report below also quotes an earlier verdict on purpose: "an earlier round said NOT CERTIFIED". The quote does not start with the verdict marker, so it cannot be misread (lesson 4).

Counts: 3 clean pgTAP files pass (37 assertions), 0 not-built files, 9 builder mutants killed, 0 certifier mutants (none saved), 0 survived, 0 crashed, 0 failed to apply.

## pgTAP files (fresh database each, no mutant)
| File | Result | Assertions |
|---|---|---|
| d_001_status_values.sql | PASS | 13 |
| d_002_shipped_frozen.sql | PASS | 15 |
| d_003_customer_isolation.sql | PASS | 9 |

## Builder mutants
| Mutant | Result | Failing assertions |
|---|---|---|
| d_001_status_allows_refunded.sql | killed | D001-02 |
| d_001_status_case_insensitive.sql | killed | D001-02 |
| d_001_status_check_dropped.sql | killed | D001-02, D001-05 |
| d_002_guard_one_column_only.sql | killed | D002-02 |
| d_002_line_trigger_dropped.sql | killed | D002-02, D002-03, D002-05, D002-06 |
| d_002_order_guard_noop.sql | killed | D002-02, D002-04 |
| d_003_get_order_ignores_customer.sql | killed | D003-04 |
| d_003_idless_lookup_added.sql | killed | D003-02 |
| d_003_table_select_granted.sql | killed | D003-07 |

## Disagreements with the cert report
None.
