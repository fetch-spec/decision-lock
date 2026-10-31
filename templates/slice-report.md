# Slice report: {{SLICE}}

Builder session. Container: `{{CONTAINER}}`. Throwaway database only; nothing run against a live database.

## Run it
`scripts/run_decision_tests.sh NNN NNN ...`  (the one command for this slice)

## Classification
| Decision | Class (DB-BUILT / DB-NOT-BUILT / NOT-DB) | Quote from the log that justifies it |
|---|---|---|
| D... | | "..." |

## Tests and mutants
| Decision | Test file | Assertions | Mutants (file: what it breaks) | Killed by |
|---|---|---|---|---|
| D... | tests/pgtap/decisions/d_NNN_slug.sql | n | tests/mutants/decisions/d_NNN_x.sql: ... | D...-xx |

## General rules
For each decision, the class it covers (every column, every child table from the catalog, every schema, every read path, every object kind), the assertion names, and the counts.

## Output of the run
Paste the runner output: PASS lines, killed lines, the final `mutants: K killed, C crashed, S survived`.

## DB defects found
Places where the database code itself breaks a decision. The builder does not fix production SQL; list each with the failing assertion name. "None" if none.

## Not done, and why
