# tap-demo

Runs the strict kill rules with no Docker and no database: plain bash tests that print TAP. It shows all four outcomes on purpose.

```bash
DL_ROOT=examples/tap-demo scripts/run_decision_tests.sh
```

| Decision | Shows | Expected line |
|---|---|---|
| D001 | strong test, two mutants | `killed ... [D001-02]`, `killed ... [D001-03]` |
| D002 | weak test (only checks a small value) | `SURVIVED (test too weak)` |
| D003 | mutant kills the test before its plan | `CRASHED (exit 0 but the test never reached its plan)` |
| D004 | decision not built yet | `NOT BUILT ... fails as required` |

The run exits 3 (one survived, one crashed, one not built counts as a problem too; see the exit code rule in the script header). Swap `DL_RUN_CMD` for `bats`, `pytest --tap-stream`, `node --test --test-reporter=tap` or `prove` to use your own framework.
