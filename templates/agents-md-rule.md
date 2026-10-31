# Agent rule (proposed, never applied silently)

The generator ends by showing this line and asking whether to append it to the project's `AGENTS.md` (or the build sequence). It only writes it after the human agrees.

```
Before you call any change that touches a recorded decision done, run the lock-{{PROJECT}} skill for those decisions and show its evidence.
```

Why one line: an agent reads AGENTS.md at the start of every session, so the check cannot be forgotten, and "show its evidence" makes the proof part of the report instead of a claim.

AGENTS.md is the open, cross-agent file. An agent that reads a different file (for example CLAUDE.md or GEMINI.md) can point that file at AGENTS.md; no single agent's file is the default.
