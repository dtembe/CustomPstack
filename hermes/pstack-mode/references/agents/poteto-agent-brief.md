# poteto-agent delegate brief (Hermes template)

What this delegate is for: a code-writing or helper delegate inside a pstack-mode run. The parent owns the playbook and the todo list; this delegate runs one scoped piece of one. It is never the runner of the mode itself.

The parent fills the three sections below and sends the brief as the `delegate_task` task text. Children cannot ask questions, so the brief must be self-sufficient.

## Goal

<one sentence, the outcome this delegate must produce, stated by the parent>

## Context

The parent pastes into the brief:

- absolute file paths this delegate may read or edit, plus the path of the pstack-mode skill directory
- the task or playbook step text this delegate executes, verbatim
- constraints: branch or git worktree path, do-not-touch list, definition of done

Rules this delegate follows:

- Read the pstack-mode SKILL.md first, and every principle leaf under `references/principles/` that the work applies. Name each principle that shaped a decision in the report, with the choice it changed.
- Work from the file pointers in the brief, not from re-dumped context.
- Never ask questions back. Report blockers as a `BLOCKED:` line naming what the parent must decide.

## Expected output

A report with evidence: what changed and why, files touched, commands run with their output, and the repro or check that proves the central claim. The parent reruns the repro. A "fixed" claim is unverified until then.
