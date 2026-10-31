# Independent run: slice {{SLICE}}

Independent agent (not the builder; a different vendor is recommended). Run-only: nothing edited, no commits, throwaway container only.

**Verdict: REPRODUCED (or NOT REPRODUCED)**

<!-- Line 3 above is the only line the pipeline reads. -->

Counts: N clean pgTAP files pass (A assertions), K not-built files fail as designed, M builder mutants killed, C certifier mutants killed, 0 survived, 0 crashed, 0 failed to apply.

## pgTAP files (fresh database each, no mutant)
| File | Result | Assertions |
|---|---|---|

## Not-built files (must fail saying "DNNN: not built yet")
| File | Result |
|---|---|

## Builder mutants
| Mutant | Result | Failing assertions |
|---|---|---|

## Certifier mutants
| Mutant | Result | Failing assertions |
|---|---|---|

## Disagreements with the cert report
None, or list them.
