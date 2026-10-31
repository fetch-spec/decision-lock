#!/usr/bin/env bash
# Writes the project-specific lock skill into a project: <project-dir>/.agents/skills/lock-<name>/
# Usage: scripts/create-lock.sh <project-dir> <name> --approved [decision-log path inside the project]
# The --approved flag is the approval gate: the human has seen templates/tool-proposal.md and said go. Without it nothing is written.
# Writes only inside .agents/skills/lock-<name>/. It never edits AGENTS.md: it prints the proposed rule instead.
# Afterwards run the self-test (lock.sh selftest); the skill is not ready until that has failed on purpose and passed again.
set -euo pipefail
proj=${1:?project dir}; name=${2:?project name}; shift 2
approved=0; log=decision-log.md
for a in "$@"; do case "$a" in --approved) approved=1;; *) log=$a;; esac; done
[ "$approved" = 1 ] || { echo '{"ok":false,"error":"tool proposal not approved: show templates/tool-proposal.md, wait for go, then pass --approved"}'; exit 1; }
skill_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
proj=$(cd "$proj" && pwd)
[ -f "$proj/$log" ] || { echo "{\"ok\":false,\"error\":\"decision log not found: $log\"}"; exit 1; }
dest="$proj/.agents/skills/lock-$name"
[ -e "$dest" ] && { echo "{\"ok\":false,\"error\":\"refusing: .agents/skills/lock-$name already exists\"}"; exit 1; }
cname=decision-lock-$name
if [ -f "$proj/decision-lock.env" ]; then c=$(grep -E '^CONTAINER=' "$proj/decision-lock.env" | tail -1 | cut -d= -f2 || true); [ -n "$c" ] && cname=$c; fi

mkdir -p "$dest/scripts" "$dest/decisions" "$dest/engine/scripts" "$dest/engine/docker"
for f in db.sh env.sh run_decision_tests.sh; do cp "$skill_dir/scripts/$f" "$dest/engine/scripts/$f"; done
cp "$skill_dir/docker/Dockerfile" "$dest/engine/docker/Dockerfile"
cp "$skill_dir/templates/project-skill/scripts/lock.sh" "$skill_dir/templates/project-skill/scripts/lock.ps1" "$dest/scripts/"
chmod +x "$dest"/scripts/lock.sh "$dest"/engine/scripts/*.sh

tmpl="$skill_dir/templates/project-skill/decisions/decision.md"
first=""; last=""; n=0
while IFS= read -r line; do
  [[ $line =~ ^-\ \*\*D([0-9]+)\*\*\ (.*)$ ]] || continue
  nnn=$(printf '%03d' "$((10#${BASH_REMATCH[1]}))"); text=${BASH_REMATCH[2]}; id=D$nnn
  [ -n "$first" ] || first=$id; last=$id; n=$((n+1))
  tests=$(cd "$proj/tests/pgtap/decisions" 2>/dev/null && ls d_${nnn}_*.sql 2>/dev/null | sed 's|^|tests/pgtap/decisions/|' | paste -sd, - | sed 's/,/, /g' || true)
  muts=$(cd "$proj/tests/mutants/decisions" 2>/dev/null && ls d_${nnn}_*.sql 2>/dev/null | sed 's|^|tests/mutants/decisions/|' | paste -sd, - | sed 's/,/, /g' || true)
  nm=$(echo "$muts" | tr ',' '\n' | grep -c . || true)
  class="(not classified yet)"; status="no test yet: write it with the builder brief"
  if [ -n "$tests" ]; then
    tf=$(ls "$proj"/tests/pgtap/decisions/d_${nnn}_*.sql | head -1)
    first_line=$(head -1 "$tf")
    if [[ $first_line == "-- DB-NOT-BUILT"* ]]; then class="DB-NOT-BUILT: the test must fail with ${id}: not built yet"; status="not built yet (fails on purpose)"
    else class=$(echo "$first_line" | sed -E 's/^-- D[0-9]+: //'); status="locked: test plus $nm mutant(s); run lock.sh run $id"; fi
  fi
  [ -n "$tests" ] || tests="none"; [ -n "$muts" ] || muts="none"
  sed -e "s|{{ID}}|$id|g" -e "s|{{TEXT}}|$(printf '%s' "$text" | sed 's/[&|\\]/\\&/g')|" -e "s|{{RULE_CLASS}}|$(printf '%s' "$class" | sed 's/[&|\\]/\\&/g')|" \
      -e "s|{{TESTS}}|$tests|" -e "s|{{MUTANTS}}|$muts|" -e "s|{{STATUS}}|$status|" "$tmpl" > "$dest/decisions/$id.md"
done < "$proj/$log"
[ "$n" -gt 0 ] || { rm -rf "$dest"; echo '{"ok":false,"error":"no decisions found: expected lines like - **D001** text"}'; exit 1; }

sed -e "s|{{PROJECT}}|$name|g" -e "s|{{FIRST_ID}}|$first|g" -e "s|{{LAST_ID}}|$last|g" -e "s|{{DECISION_LOG}}|$log|g" -e "s|{{CONTAINER}}|$cname|g" \
    -e "s|{{DRIVE}}|pgTAP (pg_prove)|" -e "s|{{ISOLATE}}|one copy and one container name per slice|" \
    "$skill_dir/templates/project-skill/SKILL.md" > "$dest/SKILL.md"

printf '{"ok":true,"cmd":"create-lock","skill":".agents/skills/lock-%s","decisions":%s,"next":"lock.sh launch, doctor, run, selftest, evidence"}\n' "$name" "$n"
echo "Proposed rule for AGENTS.md (not applied; ask the human):" >&2
sed -n '/^```$/,/^```$/p' "$skill_dir/templates/agents-md-rule.md" | sed '/^```/d' | sed "s|{{PROJECT}}|$name|g" >&2
