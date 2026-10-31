# Worked example: orders (3 decisions)

Decisions D001-D003 in `decision-log.md`, schema in `db/`, general-rule pgTAP tests in `tests/pgtap/decisions/`, nine mutants in `tests/mutants/decisions/`, sample reports in `reports/`.

## The generated lock skill

Produced by `scripts/create-lock.sh examples/orders example --approved` after the five questions and the tool approval (see `templates/five-questions.md`, `templates/tool-proposal.md`):

```
examples/orders/.claude/skills/lock-example/
  SKILL.md                 ## Launch, ## Doctor, ## Drive, ## Evidence, ## Cleanup, ## Helpers
  decisions/
    D001.md                status values: text, rule class, tests, 3 mutants, status
    D002.md                shipped order frozen
    D003.md                customer isolation
  scripts/
    lock.sh                ONE CLI: launch | doctor | run | evidence | cleanup | selftest
    lock.ps1               Windows entry point
  engine/
    scripts/db.sh, env.sh, run_decision_tests.sh
    docker/Dockerfile
```

Run it (bash and Docker; the container is `decision-lock-example`):

```
cd examples/orders/.claude/skills/lock-example
scripts/lock.sh launch      # {"ok":true,"cmd":"launch","container":"decision-lock-example",...}
scripts/lock.sh doctor      # {"ok":true,"cmd":"doctor","decisions":3,...}
scripts/lock.sh run         # {"ok":true,"cmd":"run","decisions_passed":3,"mutants_killed":9,"crashed":0,"survived":0,"problems":0,"verdict":"LOCKED",...}
scripts/lock.sh selftest D003
scripts/lock.sh evidence    # writes handoff/evidence/EVIDENCE.md
scripts/lock.sh cleanup     # removes the container
```

## Proof it can fail (break and restore)

`lock.sh selftest D003` appends the mutant `d_003_get_order_ignores_customer.sql` to `db/001_schema.sql` (breaks D003 on purpose), runs the D003 test, restores the schema file, compares hashes, and runs the test again. Recorded output, also in `handoff/evidence/selftest.json`:

| Step | Result |
|---|---|
| Unbroken system, D003 test | PASSED |
| Mutant applied (sha256 `3f85ad3a...0bf5`), D003 test | **FAILED** by named assertion `D003-04` |
| File restored, sha256 `d850729c...66b1` = hash before (`hash_match: true`) | byte for byte |
| Restored system, D003 test | **PASSED** |

A check you have never seen fail proves nothing. The kill matrix for all nine mutants is in `handoff/evidence/kill-matrix.txt`, and the verdict line is in `handoff/evidence/EVIDENCE.md`.
