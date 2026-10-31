CERT FIX {{ROUND}} for slice {{SLICE}}.

The original slice brief is `handoff/jobs/SLICE-{{SLICE}}.md`; read it in full first. A separate certifier marked the slice NOT CERTIFIED: `{{INPUT}}`.

Fix every MEDIUM and HIGH problem it lists (tests, mutants, report). Prefer a GENERAL rule over a patch for the one case the certifier tried: loop over every column, find child tables and functions from the catalog, cover every schema and read path, so the next mutant of the same kind is caught without new code. LOW problems are optional.
Do not weaken any assertion or delete any mutant. Keep every existing named assertion passing. Add every certifier mutant that survived to `tests/mutants/decisions/` if it is not there yet.
Fresh throwaway database only (`export MSYS_NO_PATHCONV=1`), never live, no commits. Do not edit the production schema code; if the database itself breaks a decision, list it under "DB defects found".
Run the full slice and show 0 survived, 0 crashed. Update `handoff/slices/{{SLICE}}.md`. Print each problem and what you did.
