# Agent rule (proposed, never applied silently)

The generator ends by showing this line and asking whether to append it to the project's `CLAUDE.md` or `AGENTS.md` (or the build sequence). It only writes it after the human agrees.

```
Before you call any change that touches a recorded decision done, run the lock-{{PROJECT}} skill for those decisions and show its evidence.
```

Why one line: an agent reads CLAUDE.md / AGENTS.md at the start of every session, so the check cannot be forgotten, and "show its evidence" makes the proof part of the report instead of a claim.
