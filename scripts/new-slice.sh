#!/usr/bin/env bash
# Make a private working copy of a project for one slice, with its own container name and rendered briefs.
# Usage: scripts/new-slice.sh <project-dir> <slice-id e.g. D021-D030> <dest-dir> [decision-log path inside the project]
# Why a copy: parallel slices must never share files or a database container (lesson 8).
# Afterwards merge the slice's new files back into the main project, excluding decision-lock.env (it differs per copy).
set -euo pipefail
src=${1:?project dir}; slice=${2:?slice id}; dest=${3:?destination dir}; log=${4:-decision-log.md}
skill_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
[ -e "$dest" ] && { echo "refusing: $dest already exists" >&2; exit 2; }
mkdir -p "$dest"
(cd "$src" && tar --exclude=.git --exclude=node_modules --exclude=decision-lock.env --exclude='*.receipt.txt' -cf - .) | (cd "$dest" && tar -xf -)
first=${slice%%-*}; lastid=${slice##*-}
cname="decision-lock-$(basename "$(cd "$src" && pwd)")-$(echo "$slice" | tr 'A-Z' 'a-z')"
{ if [ -f "$src/decision-lock.env" ]; then grep -vE '^(CONTAINER)=' "$src/decision-lock.env" || true; fi
  echo "CONTAINER=$cname"; } > "$dest/decision-lock.env"
mkdir -p "$dest/handoff/jobs" "$dest/handoff/slices" "$dest/handoff/templates" "$dest/tests/pgtap/decisions" "$dest/tests/mutants/decisions"
cp "$skill_dir"/templates/*.md "$dest/handoff/templates/"
mkdir -p "$dest/scripts"; for f in db.sh env.sh run_decision_tests.sh pipeline.sh pipeline.ps1; do cp "$skill_dir/scripts/$f" "$dest/scripts/$f"; done
mkdir -p "$dest/docker"; cp "$skill_dir/docker/Dockerfile" "$dest/docker/Dockerfile"
render() { sed -e "s|{{SLICE}}|$slice|g" -e "s|{{FIRST}}|$first|g" -e "s|{{LAST}}|$lastid|g" -e "s|{{DECISION_LOG}}|$log|g" \
               -e "s|{{CONTAINER}}|$cname|g" "$1" > "$2"; }
render "$skill_dir/templates/builder-brief.md"           "$dest/handoff/jobs/SLICE-$slice.md"
render "$skill_dir/templates/certifier-brief.md"         "$dest/handoff/jobs/SLICE-$slice-CERT.md"
render "$skill_dir/templates/independent-brief.md"       "$dest/handoff/jobs/SLICE-$slice-INDEPENDENT.md"
render "$skill_dir/templates/general-rules-fix-brief.md" "$dest/handoff/jobs/SLICE-$slice-GENRULES.md"
echo "slice copy: $dest"
echo "container : $cname"
echo "next      : DL_ROOT=$dest scripts/db.sh start && scripts/pipeline.sh --slice $slice --dir $dest"
