#!/usr/bin/env bash
# decision-lock pipeline for ONE slice, run inside that slice's own working copy.
#   build -> certify (loop to builder on NOT CERTIFIED) -> independent run (loop to builder on NOT REPRODUCED)
# Usage: scripts/pipeline.sh --slice D021-D030 --dir /path/to/slice-copy [options]
#   --max N           independent fix loops, and certify fix loops unless --cert-max is given (default 3)
#   --cert-max N      certify fix loops (default = --max)
#   --skip-build      do not run the builder first (reports already exist)
#   --fix-first FILE  run this extra builder brief once after the build (for example a general-rules fix)
#   --start N         first certify round number (to resume a half-finished run; earlier cert reports are kept as cert-(N-1))
# CLIs (paths or names on PATH; the kind is taken from the file name: claude, grok or codex):
#   --builder-cli X / DL_BUILDER_CLI          default: claude    (builder, certifier and fix sessions)
#   --independent-cli X / DL_INDEPENDENT_CLI  default: grok      (the run-only independent agent; use a different vendor)
# Exit codes: 0 REPRODUCED | 3 STOPPED (tool error, nothing to judge) | 4 still NOT CERTIFIED | 5 still NOT REPRODUCED
# Briefs are always passed by file pointer, never inline (lesson 1). A tool error is STOPPED, never looped to the builder (lesson 2).
set -uo pipefail
slice=; dir=; max=3; certmax=-1; skipbuild=0; fixfirst=; start=1
builder=${DL_BUILDER_CLI:-claude}; indep=${DL_INDEPENDENT_CLI:-grok}
while [ $# -gt 0 ]; do case "$1" in
  --slice) slice=$2; shift 2;; --dir) dir=$2; shift 2;; --max) max=$2; shift 2;; --cert-max) certmax=$2; shift 2;;
  --skip-build) skipbuild=1; shift;; --fix-first) fixfirst=$2; shift 2;; --start) start=$2; shift 2;;
  --builder-cli) builder=$2; shift 2;; --independent-cli) indep=$2; shift 2;;
  *) echo "unknown option $1" >&2; exit 64;; esac; done
[ -n "$slice" ] && [ -n "$dir" ] || { echo "need --slice and --dir" >&2; exit 64; }
cd "$dir" || { echo "no such dir $dir" >&2; exit 64; }
j=handoff/jobs; sl=handoff/slices; tp=handoff/templates
mkdir -p "$j" "$sl"
now() { date +%H:%M; }
stopped() { echo "$(now) STOPPED: $1"; exit 3; }

# run_cli <cli> <brief file> <tag>: the prompt is one line that points at the brief file.
run_cli() {
  local cli=$1 file=$2 tag=$3 kind rc prompt
  kind=$(basename "$cli" | sed -E 's/\.exe$//')
  prompt="Read the file $file in full and do exactly what it says. It is your complete brief."
  case "$kind" in
    claude) "$cli" -p "$prompt" --permission-mode acceptEdits --allowedTools "Read,Write,Edit,Glob,Grep,Bash" >"$j/SLICE-$slice-$tag.receipt.txt" 2>&1;;
    grok)   "$cli" -p "$prompt" --always-approve --disable-web-search --cwd "$PWD" >"$j/SLICE-$slice-$tag.receipt.txt" 2>&1;;
    codex)  "$cli" exec --full-auto -C "$PWD" "$prompt" >"$j/SLICE-$slice-$tag.receipt.txt" 2>&1;;
    *) stopped "unknown CLI kind '$kind' (expected claude, grok or codex; edit run_cli for another agent)";;
  esac
  rc=$?; echo "$(now) $tag exit=$rc"
  [ $rc -eq 0 ] || stopped "$kind exited $rc on $tag (see $j/SLICE-$slice-$tag.receipt.txt)"
}

# The verdict comes ONLY from the first "**Verdict:" line, never from a search of the whole file (lesson 4).
verdict_line() {
  local l; l=$(grep -m1 -E '^[[:space:]]*\*\*Verdict:' "$1") || stopped "no **Verdict: line in $1"
  printf '%s\n' "$l" | sed -E 's/^[[:space:]]*\*\*Verdict:(\*\*)?[[:space:]]*//'
}
# cert_ok / indep_ok: 0 = pass, 1 = fail, STOPPED if the line starts with neither word.
cert_ok()  { local v; v=$(verdict_line "$1"); case "$v" in "NOT CERTIFIED"*) return 1;; CERTIFIED*) return 0;; *) stopped "unreadable verdict in $1: $v";; esac; }
indep_ok() { local v; v=$(verdict_line "$1"); case "$v" in "NOT REPRODUCED"*) return 1;; REPRODUCED*) return 0;; *) stopped "unreadable verdict in $1: $v";; esac; }

# render <template> <out> ROUND INPUT: fill the fix-brief placeholders
render() { sed -e "s|{{SLICE}}|$slice|g" -e "s|{{ROUND}}|$3|g" -e "s|{{INPUT}}|$4|g" "$1" >"$2"; }

if [ $skipbuild -eq 0 ]; then
  run_cli "$builder" "$j/SLICE-$slice.md" BUILD
  [ -f "$sl/$slice.md" ] || stopped "builder wrote no slice report"
fi
[ -n "$fixfirst" ] && run_cli "$builder" "$fixfirst" GAPFIX

# certify loop
[ "$certmax" -lt 0 ] && certmax=$max
last=$((start+certmax))
for ((i=start; i<=last; i++)); do
  [ -f "$sl/$slice-cert.md" ] && mv -f "$sl/$slice-cert.md" "$sl/$slice-cert-$((i-1)).md"
  run_cli "$builder" "$j/SLICE-$slice-CERT.md" "CERT$i"
  [ -f "$sl/$slice-cert.md" ] || stopped "certifier wrote no report"
  if cert_ok "$sl/$slice-cert.md"; then echo "$(now) CERTIFIED on round $i"; break; fi
  if [ $i -ge $last ]; then echo "$(now) RESULT: STILL NOT CERTIFIED after $certmax fix loops"; exit 4; fi
  cp "$sl/$slice-cert.md" "$sl/$slice-cert-fixinput-$i.md"
  render "$tp/cert-fix-brief.md" "$j/SLICE-$slice-CFIX$i.md" "$i" "$sl/$slice-cert-fixinput-$i.md"
  run_cli "$builder" "$j/SLICE-$slice-CFIX$i.md" "CFIX$i"
done

# independent loop
run_indep() {
  rm -f "$sl/$slice-independent-run.md"
  run_cli "$indep" "$j/SLICE-$slice-INDEPENDENT.md" "$1"
  [ -f "$sl/$slice-independent-run.md" ] || stopped "independent agent wrote no report ($1)"
}
run_indep IND0
for ((i=1; i<=max; i++)); do
  if indep_ok "$sl/$slice-independent-run.md"; then
    echo "$(now) RESULT: REPRODUCED after $((i-1)) fix loops"; tail -25 "$sl/$slice-independent-run.md"; exit 0
  fi
  cp "$sl/$slice-independent-run.md" "$sl/$slice-independent-run-$i.md"
  render "$tp/independent-fix-brief.md" "$j/SLICE-$slice-IFIX$i.md" "$i" "$sl/$slice-independent-run-$i.md"
  run_cli "$builder" "$j/SLICE-$slice-IFIX$i.md" "IFIX$i"
  run_indep "IND$i"
done
if indep_ok "$sl/$slice-independent-run.md"; then echo "$(now) RESULT: REPRODUCED after $max fix loops"; exit 0
else echo "$(now) RESULT: STILL NOT REPRODUCED after $max loops"; exit 5; fi
