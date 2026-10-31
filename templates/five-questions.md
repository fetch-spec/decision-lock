# The five questions (discovery)

Before writing anything, the generator reads the project and answers these five questions. Each answer is one or two lines with the file or command that proves it. If an answer cannot be found, ask the human; do not guess.

| # | Question | Asks |
|---|---|---|
| 1 | **Decisions** | Where is the decision log? How are decisions numbered (`D001`, `D002`, ...)? |
| 2 | **Run** | How is a throwaway copy of the system started (container, temp database, temp directory)? |
| 3 | **Drive** | Which test framework asserts each decision (pgTAP, pytest, jest, ...)? |
| 4 | **Observe** | What evidence is kept (per-decision report, kill matrix, receipts, verdict line)? |
| 5 | **Isolate** | Can slices run in parallel, each with its own copy and its own container and port? |

## Worked example (the orders example in `examples/orders/`)

1. **Decisions.** `decision-log.md` in the project root. One entry per line, `- **D001** text`, ids D001..D003. Slices of 10.
2. **Run.** Docker image `decision-lock-pg:16` (Postgres 16 + pgTAP), container `decision-lock-example`, data on tmpfs, project mounted read-only at `/work`. The schema in `db/*.sql` is applied in name order to a fresh database for every test file and every mutant.
3. **Drive.** pgTAP through `pg_prove`. Tests in `tests/pgtap/decisions/d_NNN_*.sql`, assertions named `DNNN-xx`. Mutants are SQL files in `tests/mutants/decisions/d_NNN_*.sql`.
4. **Observe.** Per run: one line per decision (`PASS clean`, `killed <mutant> [assertions]`), the kill matrix, a JSON summary, and a verdict line (`LOCKED` or `NOT LOCKED`). Per slice: builder report, certifier report, independent report. Plus the "Proof it can fail" record from the self-test.
5. **Isolate.** Yes. `scripts/new-slice.sh` makes one copy and one container name per slice, so slices run in parallel without sharing a database.

Answers feed the generated skill: Decisions -> `decisions/`, Run -> `## Launch`, Drive -> `## Drive`, Observe -> `## Evidence`, Isolate -> `## Cleanup` and the container name.
