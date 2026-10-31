---
# Optional convenience: a slash-command wrapper around the plain instruction "run the create-decision-lock skill" (SKILL.md). Not required.
description: Build a project-specific lock-<project> skill (five questions, tool approval, self-test, agent rule)
---

Use the decision-lock skill to run its generator flow in the current project. Follow SKILL.md section "create-decision-lock" exactly:

1. Read the project and answer the five questions (templates/five-questions.md): Decisions, Run, Drive, Observe, Isolate. Show the answers.
2. Fill templates/tool-proposal.md with the tools you want, what each does and why this project needs it. Then STOP and wait for my go. Explain any tool or offer an alternative if I ask.
3. After my go, run `scripts/create-lock.sh <project-dir> <name> --approved` to write `.agents/skills/lock-<name>/`.
4. Run `lock.sh launch`, `lock.sh doctor`, `lock.sh run`, then `lock.sh selftest`. Do not call the skill ready until the self-test shows the broken run FAILED by a named assertion, the file restored with matching hashes, and the run PASSED.
5. Run `lock.sh evidence`. Then propose (do not apply) the one-line rule from templates/agents-md-rule.md for AGENTS.md.

Arguments (optional): $ARGUMENTS
