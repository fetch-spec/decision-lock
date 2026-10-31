# Tool proposal

Written by the generator after the five questions, shown to the human, and then the generator STOPS. Nothing is written into the project until the human says go. The human may ask what any tool does, or for an alternative.

Project: `{{PROJECT}}`

| Tool | What it does | Why this project needs it |
|---|---|---|
| (tool) | (one line) | (one line tied to an answer of the five questions) |

## Example (orders example)

| Tool | What it does | Why this project needs it |
|---|---|---|
| Docker | Starts a throwaway Postgres container with a label so it is never mistaken for a real one | Run: every test and mutant needs a fresh database built from zero |
| pgTAP + `pg_prove` | Test assertions written in SQL, run inside the database | Drive: the decisions are about database behavior (constraints, triggers, grants) |
| `scripts/engine/` (copy of `db.sh`, `env.sh`, `run_decision_tests.sh`) | Builds the database, runs each test, applies each mutant, reports killed / survived / crashed | Observe: this is the strict runner that decides what counts as a kill |
| `lock.sh` / `lock.ps1` | One CLI over the engine: launch, doctor, run, evidence, cleanup, selftest. Every subcommand prints one JSON object | One entry point an agent can call and parse |
| `sha256sum` (or `shasum -a 256`) | Hashes a file before and after the self-test | Proof the break was restored byte for byte |

Files that will be written: `.agents/skills/lock-{{PROJECT}}/` (SKILL.md, decisions/, scripts/, engine/). Nothing outside it. The agent-rule line for AGENTS.md is proposed at the end, not applied.

**Waiting for your go.** Reply `go`, or ask about a tool, or ask for an alternative.
