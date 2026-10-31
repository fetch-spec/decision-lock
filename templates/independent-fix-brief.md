INDEPENDENT FIX {{ROUND}} for slice {{SLICE}}.

The original slice brief is `handoff/jobs/SLICE-{{SLICE}}.md`; read it in full first. An independent agent could not reproduce the result: `{{INPUT}}`.

Find the root cause of every failure it lists (environment difference, order dependence, a test relying on leftover state, a mutant that only works on your copy, a missing file) and fix it so the full slice passes on a fresh throwaway database with every mutant killed by a named assertion (0 survived, 0 crashed). If the independent report shows a tool error rather than a test failure, say so and change nothing.
Do not weaken any assertion or delete any mutant. `export MSYS_NO_PATHCONV=1`, never live, no commits. Do not edit the production schema code.
Update `handoff/slices/{{SLICE}}.md`. Print each issue and what you changed.
