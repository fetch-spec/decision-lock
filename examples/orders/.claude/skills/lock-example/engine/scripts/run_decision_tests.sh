#!/usr/bin/env bash
# Strict decision test runner.
# For each tests/pgtap/decisions/d_NNN_*.sql: prove it PASSES on a fresh DB, then apply every tests/mutants/decisions/d_NNN_*.sql
# to a fresh DB and prove the test FAILS.
#  KILLED   a mutant is killed only when a named pgTAP assertion reports "not ok" and the file still ran to its plan.
#  CRASHED  the file stopped before its plan (setup error, seal, constraint). That proves nothing and fails the run.
#  SURVIVED the test passed with the mutant applied: the test is too weak. Fails the run.
# A test file whose first line is "-- DB-NOT-BUILT" must FAIL with "DNNN: not built yet"; it needs no mutant, and it still
# makes the run exit nonzero so the gap stays visible.
# Usage: scripts/run_decision_tests.sh [NNN ...]   (no args = every decision). Run scripts/db.sh start first.
# Exit code = number of problems (0 = all decisions proven). Throwaway container only.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
skill_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$DL_ROOT"
ids=("$@")
if [ ${#ids[@]} -eq 0 ]; then
  for f in tests/pgtap/decisions/d_*.sql; do [ -e "$f" ] || continue; b=$(basename "$f"); ids+=("${b:2:3}"); done
  mapfile -t ids < <(printf '%s\n' "${ids[@]}" | sort -u)
fi
bad=0; killed=0; crashed=0; survived=0
fresh() { "$skill_dir/db.sh" fresh "$DBNAME" >/dev/null 2>&1; }
prove() { $DOCKER exec -u postgres -e PGOPTIONS='-c search_path=public,tap' -w /work/tests/pgtap/decisions "$CONTAINER" bash -c "pg_prove -d $DBNAME $*" 2>&1; }
for id in "${ids[@]}"; do
  tests=$(cd tests/pgtap/decisions 2>/dev/null && ls d_${id}_*.sql 2>/dev/null | tr '\n' ' ')
  [ -n "$tests" ] || { echo "NO TEST for D$id"; bad=$((bad+1)); continue; }
  fresh
  first=${tests%% *}
  if head -1 "tests/pgtap/decisions/$first" | grep -q '^-- DB-NOT-BUILT'; then
    if out=$(prove -v $tests); then echo "FAIL  D$id is marked DB-NOT-BUILT but passes: replace the placeholder with real assertions"
    elif echo "$out" | grep -q "D$id: not built yet"; then echo "NOT BUILT  D$id fails as required (D$id: not built yet)"
    else echo "FAIL  D$id is marked DB-NOT-BUILT but failed for another reason"; echo "$out" | tail -8; fi
    bad=$((bad+1)); continue
  fi
  if out=$(prove $tests); then echo "PASS  clean   D$id"; else echo "FAIL  clean   D$id (test should pass without a mutant)"; echo "$out" | tail -15; bad=$((bad+1)); fi
  found=0
  for m in tests/mutants/decisions/d_${id}_*.sql; do
    [ -e "$m" ] || continue; found=1
    fresh
    if ! $DOCKER exec -i -u postgres "$CONTAINER" psql -X -q -v ON_ERROR_STOP=1 -d "$DBNAME" < "$m" >/dev/null 2>&1; then
      echo "MUTANT DID NOT APPLY: $m"; bad=$((bad+1)); continue; fi
    if mout=$(prove -v $tests); then echo "SURVIVED (test too weak): $m"; bad=$((bad+1)); survived=$((survived+1))
    elif echo "$mout" | grep -qE '^not ok' && ! echo "$mout" | grep -qE 'Parse errors|Dubious|No plan'; then
      echo "killed  $(basename "$m")  [$(echo "$mout" | grep -E '^not ok' | sed -E 's/^not ok [0-9]+ - (D[0-9]+-[0-9A-Za-z]+).*/\1/' | sort -u | paste -sd, -)]"; killed=$((killed+1))
    else echo "CRASHED (no assertion failed; setup error): $m"; echo "$mout" | grep -E 'ERROR|Parse errors|Dubious' | head -3; bad=$((bad+1)); crashed=$((crashed+1)); fi
  done
  [ $found -eq 1 ] || { echo "NO MUTANT for D$id"; bad=$((bad+1)); }
done
echo "mutants: $killed killed, $crashed crashed, $survived survived"
exit $bad
