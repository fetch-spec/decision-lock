# Lock evidence: lock-example

## Verdict

LOCK VERDICT: LOCKED

## Per-decision results and kill matrix

```
PASS  clean   D001
killed  d_001_status_allows_refunded.sql  [D001-02]
killed  d_001_status_case_insensitive.sql  [D001-02]
killed  d_001_status_check_dropped.sql  [D001-02,D001-05]
PASS  clean   D002
killed  d_002_guard_one_column_only.sql  [D002-02]
killed  d_002_line_trigger_dropped.sql  [D002-02,D002-03,D002-05,D002-06]
killed  d_002_order_guard_noop.sql  [D002-02,D002-04]
PASS  clean   D003
killed  d_003_get_order_ignores_customer.sql  [D003-04]
killed  d_003_idless_lookup_added.sql  [D003-02]
killed  d_003_table_select_granted.sql  [D003-07]
```

## Proof it can fail

```json
{"ok":true,"cmd":"selftest","decision":"D003","mutant":"d_003_get_order_ignores_customer.sql","broken_run":"FAILED","failed_assertions":"D003-04","restored_file":"db/001_schema.sql","hash_before":"d850729cd198b6fb4e7347f413d6609c99653d4563307490f044251bb40866b1","hash_broken":"3f85ad3a3e2482c85a6de925567001c64b6e1200b9d1da58d9e13cb5d6400bf5","hash_after":"d850729cd198b6fb4e7347f413d6609c99653d4563307490f044251bb40866b1","hash_match":true,"restored_run":"PASSED"}
```
