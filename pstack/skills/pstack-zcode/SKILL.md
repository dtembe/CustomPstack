---
name: pstack-zcode
description: Zcode adaptation notes for the pstack plugin. Read when a pstack skill or playbook hits a Zcode-specific difference (tools, subagents, models, transcripts, setup-pstack) or when configuring or troubleshooting pstack on Zcode.
---

# pstack on Zcode

This plugin ships Lauren Tan's pstack via michael-denyer/pstack-claude, port version 0.9.138, source pin a12b047. Built by sync.sh in this repository; regenerate, do not hand-edit.

## Tool and primitive map

See poteto-mode's `references/zcode-tools.md` for the full table. Short form: Agent tool delegates use `pstack:poteto-agent` (fallback: default agent); TodoWrite, Read, Grep, Glob are unchanged; children cannot ask questions (the parent chat asks); no cloud environments (use git worktree paths).

## Model roles

Every pstack model role inherits the session model. Review panels (arena, interrogate) are single-model on Zcode. Say so plainly; do not claim diversity. Never edit model configuration without an explicit ask from the operator.

## Cursor-only skip policy (verbatim)

When a step needs one, put one line in your reply, `Skipped: <step>. <reason>.`, then go on. Do not stop, ask, or retry.

## Other Zcode differences

- setup-pstack: do not run it on Zcode. Model roles are fixed by the rules above.
- poteto-agent's cache-path fallback searches Claude Code plugin paths; on Zcode the parent must pass the absolute path to poteto-mode's SKILL.md.
- Reference-tier leaves (not registered as Zcode skills): principles at `skills/poteto-mode/references/principles/<name>.md`, other skills at `skills/poteto-mode/references/skills/<name>/SKILL.md`. Read on demand.
- Not shipped (cursor-team-kit and thermos extras; packaging decision recorded in the repository README): deslop, fix-ci, fix-merge-conflicts, get-pr-comments, make-pr-easy-to-review, what-did-i-get-done, thermos, thermo-nuclear-review, thermo-nuclear-code-quality-review.
- Update path: git pull in repo-port-denyer, re-run sync.sh, then `zcode plugins update pstack@pstack-local`.
