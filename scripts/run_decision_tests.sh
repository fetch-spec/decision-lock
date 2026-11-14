#!/usr/bin/env bash
# Strict decision test runner.
# For each d_NNN_* test: prove it PASSES on a fresh system, then apply every d_NNN_* mutant to a fresh system and prove the test FAILS.
#  KILLED   a mutant is killed only when a named assertion reports "not ok" and the test still ran to its plan.
#  CRASHED  the test stopped before its plan (setup error, seal, constraint). That proves nothing and fails the run.
#  SURVIVED the test passed with the mutant applied: the test is too weak. Fails the run.
# A test whose first line is "-- DB-NOT-BUILT" (or "# NOT-BUILT") must FAIL with "DNNN: not built yet"; it needs no mutant,
# and it still makes the run exit nonzero so the gap stays visible.
#
# Engines (DL_ENGINE, default pgtap). The kill rules above are identical in every engine; only how a fresh system is made,
# how a mutant is applied and how tests run differs.
#  pgtap  Postgres + pgTAP in a throwaway Docker container. Run scripts/db.sh start first.
#         tests/pgtap/decisions/d_NNN_*.sql, tests/mutants/decisions/d_NNN_*.sql
#  tap    Any framework that prints TAP (pytest-tap, node --test, prove, bats, ...). No Docker. Needs in decision-lock.env:
#           DL_FRESH_CMD   restore the system under test to its clean state (run from DL_ROOT), e.g. "git checkout -- src"
#           DL_RUN_CMD     run test files given as arguments; TAP on stdout, nonzero exit if any fail, e.g. "bats"
#           DL_MUTANT_CMD  apply the mutant file given as its argument, e.g. "patch -p0 -i"
#         optional: DL_TEST_DIR (default tests/decisions), DL_MUTANT_DIR (default tests/mutants/decisions)
#         TAP assertion names must start with the decision, e.g. "not ok 3 - D003-04 other customer's order is hidden".
# Usage: scripts/run_decision_tests.sh [NNN ...]   (no args = every decision)
# Exit code = number of problems (0 = all decisions proven). Throwaway systems only.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
skill_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$DL_ROOT"
ENGINE=${DL_ENGINE:-pgtap}
case $ENGINE in
  pgtap) TEST_DIR=tests/pgtap/decisions; MUT_DIR=tests/mutants/decisions ;;
  tap)   TEST_DIR=${DL_TEST_DIR:-tests/decisions}; MUT_DIR=${DL_MUTANT_DIR:-tests/mutants/decisions}
         for v in DL_FRESH_CMD DL_RUN_CMD DL_MUTANT_CMD; do [ -n "${!v:-}" ] || { echo "engine tap needs $v (see header of run_decision_tests.sh)"; exit 64; }; done ;;
  *) echo "unknown DL_ENGINE '$ENGINE' (use pgtap or tap)"; exit 64 ;;
esac

ids=("$@")
if [ ${#ids[@]} -eq 0 ]; then
  for f in "$TEST_DIR"/d_*; do [ -e "$f" ] || continue; b=$(basename "$f"); ids+=("${b:2:3}"); done
  [ ${#ids[@]} -gt 0 ] && mapfile -t ids < <(printf '%s\n' "${ids[@]}" | sort -u)
fi
bad=0; killed=0; crashed=0; survived=0

fresh() {
  case $ENGINE in
    pgtap) "$skill_dir/db.sh" fresh "$DBNAME" >/dev/null 2>&1 ;;
    tap)   bash -c "$DL_FRESH_CMD" >/dev/null 2>&1 ;;
  esac
}
# run the given test files (names relative to TEST_DIR); a leading -v asks for verbose output
prove() {
  case $ENGINE in
    pgtap) $DOCKER exec -u postgres -e PGOPTIONS='-c search_path=public,tap' -w /work/tests/pgtap/decisions "$CONTAINER" bash -c "pg_prove -d $DBNAME $*" 2>&1 ;;
    tap)   local a args=(); for a in "$@"; do [ "$a" = "-v" ] || args+=("$TEST_DIR/$a"); done
           bash -c "$DL_RUN_CMD \"\$@\"" _ "${args[@]}" 2>&1 ;;
  esac
}
apply_mutant() {
  case $ENGINE in
    pgtap) $DOCKER exec -i -u postgres "$CONTAINER" psql -X -q -v ON_ERROR_STOP=1 -d "$DBNAME" < "$1" >/dev/null 2>&1 ;;
    tap)   bash -c "$DL_MUTANT_CMD \"\$1\"" _ "$1" >/dev/null 2>&1 ;;
  esac
}
# true when the output shows the test ran to its plan (a crash before the plan must never count as a kill)
reached_plan() {
  case $ENGINE in
    pgtap) ! echo "$1" | grep -qE 'Parse errors|Dubious|No plan' ;;
    tap)   echo "$1" | awk '/^1\.\.[0-9]+/ {split($0,p,"\\.\\."); plan=p[2]} /^(not )?ok[ 0-9]/ {n++} END {exit !(plan!="" && plan+0==n)}' ;;
  esac
}
is_not_built() { head -1 "$1" | grep -qE '^(--|#|//) ?(DB-)?NOT-BUILT'; }

for id in "${ids[@]}"; do
  tests=$(cd "$TEST_DIR" 2>/dev/null && ls d_${id}_* 2>/dev/null | tr '\n' ' ')
  [ -n "$tests" ] || { echo "NO TEST for D$id"; bad=$((bad+1)); continue; }
  fresh
  first=${tests%% *}
  if is_not_built "$TEST_DIR/$first"; then
    if out=$(prove -v $tests); then echo "FAIL  D$id is marked NOT-BUILT but passes: replace the placeholder with real assertions"
    elif echo "$out" | grep -q "D$id: not built yet"; then echo "NOT BUILT  D$id fails as required (D$id: not built yet)"
    else echo "FAIL  D$id is marked NOT-BUILT but failed for another reason"; echo "$out" | tail -8; fi
    bad=$((bad+1)); continue
  fi
  if out=$(prove $tests); then echo "PASS  clean   D$id"; else echo "FAIL  clean   D$id (test should pass without a mutant)"; echo "$out" | tail -15; bad=$((bad+1)); fi
  found=0
  for m in "$MUT_DIR"/d_${id}_*; do
    [ -e "$m" ] || continue; found=1
    fresh
    if ! apply_mutant "$m"; then
      echo "MUTANT DID NOT APPLY: $m"; bad=$((bad+1)); continue; fi
    if mout=$(prove -v $tests); then
      if reached_plan "$mout"; then echo "SURVIVED (test too weak): $m"; survived=$((survived+1))
      else echo "CRASHED (exit 0 but the test never reached its plan): $m"; crashed=$((crashed+1)); fi
      bad=$((bad+1))
    elif echo "$mout" | grep -qE '^not ok' && reached_plan "$mout"; then
      echo "killed  $(basename "$m")  [$(echo "$mout" | grep -E '^not ok' | sed -E 's/^not ok [0-9]+ - (D[0-9]+-[0-9A-Za-z]+).*/\1/' | sort -u | paste -sd, -)]"; killed=$((killed+1))
    else echo "CRASHED (no assertion failed; setup error): $m"; echo "$mout" | grep -E 'ERROR|Parse errors|Dubious|No plan|Error' | head -3; bad=$((bad+1)); crashed=$((crashed+1)); fi
  done
  [ $found -eq 1 ] || { echo "NO MUTANT for D$id"; bad=$((bad+1)); }
done
fresh   # leave the system under test clean
echo "mutants: $killed killed, $crashed crashed, $survived survived"
exit $bad
