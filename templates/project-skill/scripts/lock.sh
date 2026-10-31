#!/usr/bin/env bash
# The ONE CLI of this project's lock skill. Wraps the decision-lock engine in ../engine/ (db.sh, env.sh, run_decision_tests.sh);
# the engine logic is not repeated here. Every subcommand prints exactly one JSON object on stdout, e.g. {"ok":true,...}.
# Usage: lock.sh launch | doctor | run [D001-D010 | D003 | 001 002] | evidence | cleanup | selftest [D003]
# Exit code: 0 when "ok" is true, 1 when false.
set -uo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
skill=$(cd "$here/.." && pwd)
export DL_ROOT=${DL_ROOT:-$(cd "$skill/../../.." && pwd)}      # project root: .agents/skills/lock-<project>/ is three levels below it
engine="$skill/engine/scripts"
. "$engine/env.sh"
ev_rel=handoff/evidence
ev="$DL_ROOT/$ev_rel"
cmd=${1:-}; shift || true

js() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr '\n\r\t' '   '; }
fail() { printf '{"ok":false,"cmd":"%s","error":"%s"}\n' "$cmd" "$(js "$1")"; exit 1; }
hash_of() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }
running() { [ "$($DOCKER inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" = "true" ]; }
prove() { $DOCKER exec -u postgres -e PGOPTIONS='-c search_path=public,tap' -w /work/tests/pgtap/decisions "$CONTAINER" bash -c "pg_prove $*" 2>&1; }
# D001-D003 / D003 / 003 / "001 002" / "D001,D002"  ->  one NNN per line
expand_ids() {
  local a lo hi i
  for a in $(printf '%s ' "$@" | tr ',' ' '); do
    if [[ $a =~ ^D?([0-9]+)-D?([0-9]+)$ ]]; then lo=$((10#${BASH_REMATCH[1]})); hi=$((10#${BASH_REMATCH[2]})); for ((i=lo;i<=hi;i++)); do printf '%03d\n' "$i"; done
    elif [[ $a =~ ^D?([0-9]+)$ ]]; then printf '%03d\n' "$((10#${BASH_REMATCH[1]}))"
    else fail "bad decision id: $a"; fi
  done
}

case "$cmd" in
launch)
  $DOCKER info >/dev/null 2>&1 || fail "docker daemon not reachable"
  $DOCKER image inspect "$IMAGE" >/dev/null 2>&1 || "$engine/db.sh" build >/dev/null 2>&1 || fail "image $IMAGE missing and build failed"
  "$engine/db.sh" start >/dev/null 2>&1 || fail "could not start container $CONTAINER"
  printf '{"ok":true,"cmd":"launch","container":"%s","image":"%s"}\n' "$CONTAINER" "$IMAGE" ;;

doctor)
  problems=""; add() { problems="$problems$1; "; }
  $DOCKER info >/dev/null 2>&1 || add "docker daemon not reachable"
  $DOCKER image inspect "$IMAGE" >/dev/null 2>&1 || add "image $IMAGE missing (run launch)"
  running || add "container $CONTAINER not running (run launch)"
  command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 || add "no sha256sum or shasum"
  ls "$DL_ROOT/$SCHEMA_DIR"/*.sql >/dev/null 2>&1 || add "no schema files in $SCHEMA_DIR/"
  n=0; for d in "$skill"/decisions/D*.md; do [ -e "$d" ] || continue; n=$((n+1)); id=$(basename "$d" .md); nnn=${id#D}
    ls "$DL_ROOT"/tests/pgtap/decisions/d_${nnn}_*.sql >/dev/null 2>&1 || add "$id has no test"
    head -1 "$DL_ROOT"/tests/pgtap/decisions/d_${nnn}_*.sql 2>/dev/null | grep -q '^-- DB-NOT-BUILT' || ls "$DL_ROOT"/tests/mutants/decisions/d_${nnn}_*.sql >/dev/null 2>&1 || add "$id has no mutant"
  done
  [ "$n" -gt 0 ] || add "no decisions/D*.md files"
  if [ -z "$problems" ]; then printf '{"ok":true,"cmd":"doctor","decisions":%s,"container":"%s"}\n' "$n" "$CONTAINER"
  else printf '{"ok":false,"cmd":"doctor","decisions":%s,"problems":"%s"}\n' "$n" "$(js "$problems")"; exit 1; fi ;;

run)
  running || fail "container $CONTAINER not running: run launch first"
  ids=$(expand_ids "$@") || exit 1
  mkdir -p "$ev"
  # shellcheck disable=SC2086
  "$engine/run_decision_tests.sh" $ids > "$ev/run-last.txt" 2>&1; problems=$?
  grep -E '^(PASS|killed|NOT BUILT|FAIL|SURVIVED|CRASHED|MUTANT DID NOT APPLY|NO TEST|NO MUTANT)' "$ev/run-last.txt" > "$ev/kill-matrix.txt" || true
  passed=$(grep -c '^PASS' "$ev/run-last.txt"); killed=$(grep -c '^killed' "$ev/run-last.txt")
  crashed=$(grep -c '^CRASHED' "$ev/run-last.txt"); survived=$(grep -c '^SURVIVED' "$ev/run-last.txt")
  if [ "$problems" -eq 0 ]; then verdict=LOCKED; else verdict="NOT LOCKED"; fi
  echo "LOCK VERDICT: $verdict" >> "$ev/run-last.txt"
  printf '{"ok":%s,"cmd":"run","ids":"%s","decisions_passed":%s,"mutants_killed":%s,"crashed":%s,"survived":%s,"problems":%s,"verdict":"%s","kill_matrix":"%s/kill-matrix.txt"}\n' \
    "$([ "$problems" -eq 0 ] && echo true || echo false)" "$(js "$(echo $ids)")" "$passed" "$killed" "$crashed" "$survived" "$problems" "$verdict" "$ev_rel"
  [ "$problems" -eq 0 ] ;;

evidence)
  [ -f "$ev/run-last.txt" ] || fail "no run yet: run the decisions first"
  { echo "# Lock evidence: $(basename "$skill")"; echo
    echo "## Verdict"; echo; tail -1 "$ev/run-last.txt"; echo
    echo "## Per-decision results and kill matrix"; echo; echo '```'; cat "$ev/kill-matrix.txt"; echo '```'; echo
    echo "## Proof it can fail"; echo
    if [ -f "$ev/selftest.json" ]; then echo '```json'; cat "$ev/selftest.json"; echo '```'; else echo "Not recorded yet: run \`lock.sh selftest\`. A check you have never seen fail proves nothing."; fi
  } > "$ev/EVIDENCE.md"
  printf '{"ok":true,"cmd":"evidence","report":"%s/EVIDENCE.md","verdict":"%s","proof_it_can_fail":%s}\n' "$ev_rel" "$(tail -1 "$ev/run-last.txt" | sed 's/^LOCK VERDICT: //')" "$([ -f "$ev/selftest.json" ] && echo true || echo false)" ;;

cleanup)
  "$engine/db.sh" stop >/dev/null 2>&1 || fail "could not remove container $CONTAINER"
  printf '{"ok":true,"cmd":"cleanup","removed":"%s"}\n' "$CONTAINER" ;;

selftest)
  # Break one thing on purpose, prove the check fails by a named assertion, put it back byte for byte, prove it passes.
  running || fail "container $CONTAINER not running: run launch first"
  want=$(expand_ids "$@" | head -1)
  if [ -z "$want" ]; then for f in "$DL_ROOT"/tests/mutants/decisions/d_*.sql; do [ -e "$f" ] || continue; b=$(basename "$f"); want=${b:2:3}; break; done; fi
  [ -n "$want" ] || fail "no decision with a mutant found"
  test_f=$(ls "$DL_ROOT"/tests/pgtap/decisions/d_${want}_*.sql 2>/dev/null | head -1); mut_f=$(ls "$DL_ROOT"/tests/mutants/decisions/d_${want}_*.sql 2>/dev/null | head -1)
  [ -n "$test_f" ] && [ -n "$mut_f" ] || fail "D$want needs a test and a mutant"
  target=$(ls "$DL_ROOT/$SCHEMA_DIR"/*.sql | sort | tail -1)
  backup=$(mktemp); cp "$target" "$backup"; h_before=$(hash_of "$target")
  restore() { cp "$backup" "$target"; }
  trap 'restore; rm -f "$backup"' EXIT
  tname=$(basename "$test_f")
  "$engine/db.sh" fresh "$DBNAME" >/dev/null 2>&1 || fail "baseline database build failed"
  prove -d "$DBNAME" "$tname" >/dev/null || fail "baseline: D$want test does not pass on the unbroken system"
  { printf '\n'; cat "$mut_f"; } >> "$target"                     # BREAK: the mutant is appended to the last schema file
  h_broken=$(hash_of "$target")
  "$engine/db.sh" fresh "$DBNAME" >/dev/null 2>&1 || { restore; fail "the broken system did not build (mutant did not apply)"; }
  broken_out=$(prove -v -d "$DBNAME" "$tname"); broken_rc=$?
  names=$(echo "$broken_out" | grep -E '^not ok' | sed -E 's/^not ok [0-9]+ - (D[0-9]+-[0-9A-Za-z]+).*/\1/' | sort -u | paste -sd, -)
  restore                                                          # RESTORE
  h_after=$(hash_of "$target")
  [ "$h_after" = "$h_before" ] || fail "restore is not byte-for-byte: hash $h_before became $h_after"
  if [ "$broken_rc" -eq 0 ] || [ -z "$names" ] || echo "$broken_out" | grep -qE 'Parse errors|Dubious|No plan'; then
    fail "the broken system was NOT caught by a named assertion: a check you have never seen fail proves nothing"; fi
  "$engine/db.sh" fresh "$DBNAME" >/dev/null 2>&1 || fail "restored database build failed"
  prove -d "$DBNAME" "$tname" >/dev/null || fail "after restore: D$want test does not pass again"
  mkdir -p "$ev"
  printf '{"ok":true,"cmd":"selftest","decision":"D%s","mutant":"%s","broken_run":"FAILED","failed_assertions":"%s","restored_file":"%s","hash_before":"%s","hash_broken":"%s","hash_after":"%s","hash_match":true,"restored_run":"PASSED"}\n' \
    "$want" "$(basename "$mut_f")" "$names" "${target#"$DL_ROOT"/}" "$h_before" "$h_broken" "$h_after" | tee "$ev/selftest.json" ;;

*) printf '{"ok":false,"cmd":"%s","error":"usage: lock.sh launch|doctor|run [ids]|evidence|cleanup|selftest [id]"}\n' "$(js "$cmd")"; exit 64 ;;
esac
