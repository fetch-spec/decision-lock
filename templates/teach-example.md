# Teach mode: add a decision from one example

A human adds a decision without writing a test. Give the generated skill ONE example of good data and ONE of bad data (or one real failing case). The builder turns it into a test plus a mutant.

## Fill in

- **Decision id and text** (plain words, one decision): `D0NN ...`
- **Good example** (must be accepted): e.g. `INSERT ... VALUES (...)`, or a request, or a record
- **Bad example** (must be refused): the same, with the one thing wrong
- **Or: one real failing case** (what happened, with the input that caused it)

## What the builder does with it

1. Adds the decision to the decision log and creates `decisions/D0NN.md`.
2. Writes `tests/.../d_0NN_*.sql`: the good example must pass, the bad example must be refused with the real error code, then generalizes to the whole rule (every column, every path), not just the two examples.
3. Writes at least one mutant that removes exactly this protection, and shows the test fails by a named assertion (`D0NN-xx`) with the mutant and passes without it.
4. Runs `lock.sh run D0NN` and `lock.sh selftest D0NN`, and shows the evidence.

## Example

- Decision: `D004 A paid order cannot go back to new.`
- Good: `UPDATE orders.customer_order SET status='shipped' WHERE status='paid'` succeeds.
- Bad: `UPDATE orders.customer_order SET status='new' WHERE status='paid'` is refused.
- Builder output: test `d_004_no_status_rewind.sql` (checks every forward and backward status pair), mutant `d_004_rewind_allowed.sql` (drops the trigger), killed by `D004-03`.
